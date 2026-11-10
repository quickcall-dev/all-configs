from __future__ import annotations

import asyncio
import os
import signal
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from rich.rule import Rule
from rich.text import Text
from textual import events, work
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen, Screen
from textual.widgets import (
    Button,
    DataTable,
    Footer,
    Input,
    ProgressBar,
    RichLog,
    Static,
)

from tui.modules import PLATFORM, Module, Status
from tui.runner import LineSplitter, PtyProcess, looks_like_password, looks_like_prompt, strip_ansi
from tui.theme import tones
from tui.widgets import ModuleTable

# glyph, label, tone (a key of tones())
STATUS_BADGE = {
    Status.CHECKING: ("…", "checking", "muted"),
    Status.INSTALLED: ("●", "installed", "ok"),
    Status.PARTIAL: ("◐", "partial", "warn"),
    Status.MISSING: ("○", "missing", "muted"),
    Status.UNKNOWN: ("◌", "unknown", "muted"),
}
STATUS_WIDTH = 11

# How long a partial line must sit idle before it is treated as a prompt.
PROMPT_IDLE_SECONDS = 0.35

SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"


def status_text(module: Module, tone: dict[str, str]) -> Text:
    if module.last_run_failed:
        glyph, label, key = "✗", "failed", "err"
    else:
        glyph, label, key = STATUS_BADGE[module.status]
    return Text.assemble((glyph, tone[key]), " ", (label, tone["muted"] if key == "muted" else ""))


def topbar(crumb: str) -> ComposeResult:
    with Horizontal(id="topbar"):
        yield Static("◆ all-configs", id="brand")
        yield Static(crumb, id="crumb")
        yield Static("", id="summary")


# ─── Main screen ────────────────────────────────────────────────────────────


class MainScreen(Screen):
    """Search, multi-select and status for every module on this platform."""

    BINDINGS = [
        # esc steps back one layer: search text, then filter, then selection
        Binding("escape", "clear_search", "Clear search"),
        Binding("escape", "clear_selection", "Clear selection"),
        Binding("escape", "leave_search", "Back", show=False),
        Binding("slash", "focus_search", "Search"),
        Binding("a", "select_all", "All"),
        Binding("n", "select_none", "None"),
        Binding("i", "invert", "Invert"),
        Binding("enter", "install", "Install", show=False),
        Binding("u", "uninstall", "Uninstall"),
        Binding("r", "rescan", "Rescan"),
        Binding("question_mark", "help", "Help"),
        Binding("q", "app.quit", "Quit"),
    ]

    def compose(self) -> ComposeResult:
        yield from topbar("")
        with Horizontal(id="search-row"):
            yield Static("/", id="search-icon")
            yield Input(placeholder="search name, description, kind or status", id="search", compact=True)
        yield ModuleTable(id="module-table")
        yield Static("", id="empty")
        yield Static("", id="selection-bar")
        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#empty", Static).border_title = "Modules"
        table = self.query_one(ModuleTable)
        table.border_title = "Modules"
        table.add_column("", key="sel", width=1)
        table.add_column("Module", key="name")
        table.add_column("Kind", key="kind", width=6)
        table.add_column("Status", key="status", width=STATUS_WIDTH)
        table.add_column("Description", key="desc")
        self.app.theme_changed_signal.subscribe(self, lambda _: self.refresh_rows())
        self.refresh_rows()
        table.focus()

    # data helpers -------------------------------------------------------

    @property
    def modules(self) -> list[Module]:
        return self.app.modules

    @property
    def selected(self) -> set[str]:
        return self.app.selected

    def visible_modules(self) -> list[Module]:
        query = self.query_one("#search", Input).value.strip().lower()
        if not query:
            return list(self.modules)
        return [
            m
            for m in self.modules
            if query in m.name.lower()
            or query in m.description.lower()
            or query == m.kind
            or query == m.status.value
        ]

    def _desc_width(self) -> int:
        # sel + kind + status + name columns, 2 cells padding per column (5),
        # table border (2), screen margin (2), vertical scrollbar (1)
        name_w = max((len(m.name) for m in self.modules), default=10)
        fixed = 1 + 6 + STATUS_WIDTH + name_w + 5 * 2 + 2 + 2 + 1
        return max(16, self.size.width - fixed)

    def _row(self, module: Module, tone: dict[str, str]) -> tuple:
        picked = module.name in self.selected
        mark = Text("▍", style=tone["accent"]) if picked else Text(" ")
        name = Text(module.name, style=f"bold {tone['accent']}" if picked else "bold")
        desc = module.description
        width = self._desc_width()
        if len(desc) > width:
            desc = desc[: width - 1] + "…"
        muted = tone["muted"]
        return (mark, name, Text(module.kind, style=muted), status_text(module, tone), Text(desc, style=muted))

    def refresh_rows(self) -> None:
        table = self.query_one(ModuleTable)
        current = None
        if table.row_count and 0 <= table.cursor_row < table.row_count:
            current = table.coordinate_to_cell_key((table.cursor_row, 0)).row_key.value
        table.clear()
        rows = self.visible_modules()
        tone = tones(self.app)
        for module in rows:
            table.add_row(*self._row(module, tone), key=module.name)
        names = [m.name for m in rows]
        if current in names:
            table.move_cursor(row=names.index(current))
        query = self.query_one("#search", Input).value.strip()
        empty = self.query_one("#empty", Static)
        empty.display = bool(self.modules) and not rows
        empty.update(f"No module matches “{query}”.  esc clears the search")
        table.display = not empty.display
        self.update_bars()
        self.refresh_bindings()

    def refresh_module(self, module: Module) -> None:
        table = self.query_one(ModuleTable)
        if module.name not in table.rows:
            return
        for key, value in zip(("sel", "name", "kind", "status", "desc"), self._row(module, tones(self.app))):
            table.update_cell(module.name, key, value)

    def update_bars(self) -> None:
        tone = tones(self.app)
        installed = sum(m.status is Status.INSTALLED for m in self.modules)
        checking = any(m.status is Status.CHECKING for m in self.modules)
        summary = Text.assemble(
            (PLATFORM, "bold"),
            ("  ·  ", tone["muted"]),
            (f"{installed}", tone["ok"]),
            (f"/{len(self.modules)} installed", tone["muted"]),
        )
        if checking:
            summary.append("  ·  detecting…", style=tone["muted"])
        self.query_one("#summary", Static).update(summary)
        table = self.query_one(ModuleTable)
        shown = table.row_count
        table.border_subtitle = f"{shown} of {len(self.modules)}" if shown != len(self.modules) else ""
        sel = [m.name for m in self.modules if m.name in self.selected]
        if sel:
            bar = Text.assemble((f"{len(sel)} selected", f"bold {tone['accent']}"), ("  ", ""), (" · ".join(sel), ""))
        else:
            bar = Text("Nothing selected. enter installs the highlighted module, space adds it to a batch.", style=tone["muted"])
        self.query_one("#selection-bar", Static).update(bar)

    def on_resize(self, event: events.Resize) -> None:
        if self.modules:
            self.refresh_rows()

    # search -------------------------------------------------------------

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "search":
            self.refresh_rows()
            self.refresh_bindings()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "search":
            self.query_one(ModuleTable).focus()

    def on_key(self, event: events.Key) -> None:
        search = self.query_one("#search", Input)
        if search.has_focus and event.key == "down":
            self.query_one(ModuleTable).focus()
            event.stop()

    def on_descendant_focus(self) -> None:
        self.refresh_bindings()

    def check_action(self, action: str, parameters: tuple[object, ...]) -> bool | None:
        if not self.is_mounted:
            return True
        search = self.query_one("#search", Input)
        if action == "clear_search":
            return bool(search.value)
        if action == "leave_search":
            return search.has_focus and not search.value
        if action == "clear_selection":
            return bool(self.selected) and not search.value
        return True

    def action_focus_search(self) -> None:
        self.query_one("#search", Input).focus()

    def action_clear_search(self) -> None:
        self.query_one("#search", Input).value = ""
        self.query_one(ModuleTable).focus()

    def action_leave_search(self) -> None:
        self.query_one(ModuleTable).focus()

    def action_clear_selection(self) -> None:
        self.selected.clear()
        self.refresh_rows()

    # selection ----------------------------------------------------------

    def _cursor_module(self) -> Module | None:
        table = self.query_one(ModuleTable)
        if not table.row_count:
            return None
        name = table.coordinate_to_cell_key((table.cursor_row, 0)).row_key.value
        return self.app.module_by_name.get(name)

    def action_toggle(self) -> None:
        module = self._cursor_module()
        if module is None:
            return
        self.selected.symmetric_difference_update({module.name})
        self.refresh_module(module)
        self.update_bars()
        self.refresh_bindings()

    def _set_visible(self, mode: str) -> None:
        for module in self.visible_modules():
            if mode == "all":
                self.selected.add(module.name)
            elif mode == "none":
                self.selected.discard(module.name)
            else:
                self.selected.symmetric_difference_update({module.name})
            self.refresh_module(module)
        self.update_bars()
        self.refresh_bindings()

    def action_select_all(self) -> None:
        self._set_visible("all")

    def action_select_none(self) -> None:
        self._set_visible("none")

    def action_invert(self) -> None:
        self._set_visible("invert")

    def _targets(self) -> list[Module]:
        """Selected modules, or the one under the cursor when nothing is selected."""
        chosen = [m for m in self.modules if m.name in self.selected]
        if not chosen and (module := self._cursor_module()):
            chosen = [module]
        return chosen

    # actions ------------------------------------------------------------

    def action_install(self) -> None:
        targets = self._targets()
        if targets:
            self.app.request_install(targets)

    def action_uninstall(self) -> None:
        targets = self._targets()
        if targets:
            self.app.request_uninstall(targets)

    def action_rescan(self) -> None:
        self.app.rescan()

    def action_help(self) -> None:
        self.app.push_screen(HelpScreen(self.active_bindings))


# ─── Help ───────────────────────────────────────────────────────────────────


class HelpScreen(ModalScreen[None]):
    BINDINGS = [Binding("escape,q,question_mark", "dismiss", "Close")]

    def __init__(self, bindings) -> None:
        super().__init__()
        self._key_bindings = bindings

    def compose(self) -> ComposeResult:
        tone = tones(self.app)
        lines = Text()
        lines.append("KEYS\n", style=f"bold {tone['muted']}")
        rows = [("enter", "Install the selection, or the highlighted module")]
        for active in self._key_bindings.values():
            b = active.binding
            if b.show and b.description and b.description not in ("Install", "Help"):
                rows.append((self.app.get_key_display(b), b.description))
        rows.append(("^p", "Command palette (themes, quit)"))
        for key, desc in rows:
            lines.append(f"  {key:>6}  ", style=f"bold {tone['accent']}")
            lines.append(f"{desc}\n")
        lines.append("\nSTATUS\n", style=f"bold {tone['muted']}")
        for status, meaning in (
            (Status.INSTALLED, "tool present and config applied"),
            (Status.PARTIAL, "one of the two is missing; install re-applies"),
            (Status.MISSING, "not installed"),
            (Status.UNKNOWN, "nothing to detect; install is safe to re-run"),
        ):
            glyph, label, key = STATUS_BADGE[status]
            lines.append(f"  {glyph} ", style=tone[key])
            lines.append(f"{label:<10}", style="bold")
            lines.append(f"{meaning}\n", style=tone["muted"])
        lines.append(
            "\nUninstall works only for app and cli modules managed by a package "
            "manager. Config modules never uninstall the tool they configure.",
            style=tone["muted"],
        )
        with Vertical(id="dialog", classes="help") as dialog:
            dialog.border_title = "Help"
            dialog.border_subtitle = "esc to close"
            yield Static(lines)
            with Horizontal(classes="buttons"):
                yield Button("Close", id="close", compact=True)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss()


# ─── Confirm ────────────────────────────────────────────────────────────────


@dataclass
class Plan:
    action: str  # "install" | "uninstall"
    run: list[Module]
    notes: list[tuple[str, list[str]]] = field(default_factory=list)


class ConfirmScreen(ModalScreen[bool]):
    BINDINGS = [
        Binding("escape,n", "cancel", "Cancel"),
        Binding("y", "confirm", "Confirm"),
    ]

    def __init__(self, plan: Plan) -> None:
        super().__init__()
        self.plan = plan

    def compose(self) -> ComposeResult:
        tone = tones(self.app)
        action = self.plan.action
        verb = action.capitalize()
        danger = action in ("uninstall", "abort")
        count = len(self.plan.run)
        body = Text()
        if action == "abort":
            body.append("Stop the running step and skip the rest?\n", style="bold")
            body.append("The current installer gets SIGTERM; finished steps stay as they are.\n\n", style=tone["muted"])
        else:
            noun = "module" if count == 1 else "modules"
            body.append(f"{verb} {count} {noun}?\n\n", style="bold")
        name_w = max((len(m.name) for m in self.plan.run), default=0)
        for module in self.plan.run:
            if action == "install":
                body.append("  + ", style=tone["ok"])
            else:
                body.append("  − ", style=tone["err"])
            body.append(f"{module.name:<{name_w}}", style="bold")
            if action == "uninstall":
                body.append(f"   removes {' '.join(module.uninstall_packages)}", style=tone["err"])
            elif action == "install" and module.status is Status.INSTALLED:
                body.append("   re-apply", style=tone["muted"])
            body.append("\n")
        for title, names in self.plan.notes:
            body.append(f"\n{title}\n", style=f"bold {tone['warn']}")
            body.append("  " + ", ".join(names) + "\n", style=tone["muted"])
        with Vertical(id="dialog", classes="danger" if danger else "") as dialog:
            dialog.border_title = "Abort run" if action == "abort" else verb
            dialog.border_subtitle = f"y {action} · esc cancel"
            with VerticalScroll(id="confirm-body"):
                yield Static(body)
            with Horizontal(classes="buttons"):
                yield Button("Cancel", id="cancel", compact=True)
                yield Button(verb, id="confirm", variant="error" if danger else "primary", compact=True)

    def on_mount(self) -> None:
        danger = self.plan.action in ("uninstall", "abort")
        self.query_one("#cancel" if danger else "#confirm", Button).focus()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "confirm")

    def action_confirm(self) -> None:
        self.dismiss(True)

    def action_cancel(self) -> None:
        self.dismiss(False)


# ─── Run ────────────────────────────────────────────────────────────────────


@dataclass
class Job:
    module: Module
    argv: list[str]
    state: str = "pending"  # pending | running | ok | failed | skipped
    seconds: float = 0.0
    returncode: int | None = None


@dataclass
class RunResult:
    action: str
    jobs: list[Job]
    log_path: Path | None
    aborted: bool

    @property
    def failed(self) -> list[Job]:
        return [j for j in self.jobs if j.state == "failed"]


# glyph, tone (a key of tones()); running uses SPINNER
JOB_BADGE = {
    "pending": ("○", "muted"),
    "running": ("", "accent"),
    "ok": ("✓", "ok"),
    "failed": ("✗", "err"),
    "skipped": ("–", "muted"),
}


def log_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return Path(base) / "all-configs" / "logs"


class RunScreen(Screen[RunResult]):
    """Runs jobs one by one in a pty, streams output, answers prompts."""

    BINDINGS = [
        Binding("escape", "abort", "Abort"),
        Binding("escape", "back", "Back"),
        Binding("ctrl+r", "retry", "Retry failed"),
        Binding("ctrl+l", "focus_log", "Log"),
    ]

    def __init__(self, action: str, jobs: list[Job], root: Path) -> None:
        super().__init__()
        self.action = action
        self.jobs = jobs
        self.root = root
        self.proc: PtyProcess | None = None
        self.running = False
        self.aborting = False
        self.aborted = False
        self.log_path: Path | None = None
        self._log_file = None
        self._last_output = 0.0
        self._partial = ""
        self._masked_prompt: str | None = None

    def compose(self) -> ComposeResult:
        yield from topbar(f"›  {self.action}")
        with Horizontal(id="run-body"):
            yield DataTable(id="jobs", cursor_type="none", show_header=False, show_cursor=False)
            with Vertical(id="run-main"):
                yield RichLog(id="log", wrap=True, markup=False, highlight=False, max_lines=20000)
                yield Static("", id="live")
                yield Input(placeholder="type a reply for the installer and press enter", id="reply")
        with Horizontal(id="run-bar"):
            yield ProgressBar(total=len(self.jobs), show_eta=False, id="progress")
            yield Button("Abort", id="abort", variant="error", compact=True)
            yield Button("Retry failed", id="retry", disabled=True, compact=True)
            yield Button("Done", id="done", variant="primary", disabled=True, compact=True)
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#jobs", DataTable)
        table.border_title = "Steps"
        table.add_column("s", key="s", width=1)
        table.add_column("name", key="name")
        table.add_column("t", key="t", width=4)
        for job in self.jobs:
            table.add_row(*self._job_row(job), key=job.module.name)
        log = self.query_one("#log", RichLog)
        log.border_title = "Output"
        self._open_log()
        if self.log_path:
            log.write(Text(f"log  {self._short(self.log_path)}", style=tones(self.app)["muted"]))
        self._update_summary()
        self.set_interval(0.15, self._tick)
        self.start(self.jobs)

    # rendering ----------------------------------------------------------

    def _job_row(self, job: Job) -> tuple:
        tone = tones(self.app)
        glyph, key = JOB_BADGE[job.state]
        if job.state == "running":
            glyph = SPINNER[int(time.monotonic() * 10) % len(SPINNER)]
        muted = tone["muted"]
        name_style = {"running": "bold", "pending": muted, "skipped": f"{muted} strike"}.get(job.state, "")
        secs = f"{job.seconds:.0f}s" if job.state not in ("pending", "skipped") else ""
        return Text(glyph, style=tone[key]), Text(job.module.name, style=name_style), Text(secs, style=muted, justify="right")

    def _refresh_job(self, job: Job) -> None:
        table = self.query_one("#jobs", DataTable)
        for key, value in zip(("s", "name", "t"), self._job_row(job)):
            table.update_cell(job.module.name, key, value)

    def _update_summary(self) -> None:
        tone = tones(self.app)
        done = sum(j.state in ("ok", "failed", "skipped") for j in self.jobs)
        failed = sum(j.state == "failed" for j in self.jobs)
        text = Text.assemble((f"{done}/{len(self.jobs)}", "bold"), (" done", tone["muted"]))
        if failed:
            text.append(f"  ·  {failed} failed", style=tone["err"])
        self.query_one("#summary", Static).update(text)
        self.query_one("#jobs", DataTable).border_subtitle = f"{done}/{len(self.jobs)}"
        self.query_one("#progress", ProgressBar).update(progress=done)

    @staticmethod
    def _short(path: Path) -> str:
        home = str(Path.home())
        return str(path).replace(home, "~", 1)

    def _write(self, line: str, tone: str | None = None) -> None:
        """Log a line; ``tone`` (a key of tones()) styles the TUI's own messages."""
        style = None
        if tone:
            style = tones(self.app)[tone] if tone == "muted" else f"bold {tones(self.app)[tone]}"
        if style is None and self._masked_prompt and strip_ansi(line) == self._masked_prompt:
            line += " ********"
            self._masked_prompt = None
        log = self.query_one("#log", RichLog)
        log.write(Text(line, style=style) if style else Text.from_ansi(line))
        self._log_text(strip_ansi(line))

    def _log_text(self, line: str) -> None:
        if self._log_file:
            self._log_file.write(line + "\n")
            self._log_file.flush()

    def _write_header(self, job: Job) -> None:
        tone = tones(self.app)
        log = self.query_one("#log", RichLog)
        log.write("")
        title = Text.assemble((" ▸ ", tone["accent"]), (job.module.name, f"bold {tone['accent']}"), " ")
        log.write(Rule(title, align="left", style=tone["muted"], characters="─"), expand=True)
        self._log_text(f"── {job.module.name} ──")
        log.border_subtitle = job.module.name

    def _open_log(self) -> None:
        try:
            directory = log_dir()
            directory.mkdir(parents=True, exist_ok=True)
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            self.log_path = directory / f"{stamp}-{self.action}.log"
            self._log_file = self.log_path.open("w")
        except OSError:
            self.log_path = None
            self._log_file = None

    # running ------------------------------------------------------------

    @work(exclusive=True, group="run")
    async def start(self, jobs: list[Job]) -> None:
        self.running = True
        self.aborting = False
        self.refresh_bindings()
        self.query_one("#log", RichLog).set_classes("")
        self._set_buttons()
        for job in jobs:
            if self.aborting:
                job.state = "skipped"
                self._refresh_job(job)
                continue
            await self._run_job(job)
            self._update_summary()
        self.running = False
        self.aborted = self.aborting
        self.refresh_bindings()
        self.query_one("#live", Static).update("")
        failed = [j.module.name for j in self.jobs if j.state == "failed"]
        self._write("")
        if self.aborted:
            self._write("■ Aborted.", "warn")
            outcome = "warn"
        elif failed:
            self._write(f"✗ Finished with {len(failed)} failed: {', '.join(failed)}", "err")
            outcome = "err"
        else:
            self._write(f"✓ All {len(self.jobs)} finished successfully.", "ok")
            outcome = "ok"
        if self.log_path:
            self._write(f"  log  {self._short(self.log_path)}", "muted")
        log = self.query_one("#log", RichLog)
        log.border_subtitle = {"ok": "done", "err": "failed", "warn": "aborted"}[outcome]
        log.set_classes(outcome)
        self._set_buttons()
        self.query_one("#done", Button).focus()

    async def _run_job(self, job: Job) -> None:
        job.state = "running"
        job.seconds = 0.0
        self._refresh_job(job)
        self._write_header(job)
        started = time.monotonic()
        cols = max(40, self.query_one("#log", RichLog).size.width - 2)
        env = dict(os.environ)
        env.update(TERM="xterm-256color", COLUMNS=str(cols), ALL_CONFIGS_TUI="1")
        env.pop("LINES", None)
        self.proc = PtyProcess(job.argv, cwd=self.root, env=env, cols=cols)
        splitter = LineSplitter()
        try:
            await self.proc.start()
        except OSError as exc:
            self._write(f"could not start: {exc}", "err")
            job.state = "failed"
            self._refresh_job(job)
            return

        waiter = asyncio.ensure_future(self.proc.wait())
        while True:
            reader = asyncio.ensure_future(self.proc.read())
            done, _ = await asyncio.wait({reader, waiter}, return_when=asyncio.FIRST_COMPLETED)
            if reader in done:
                chunk = reader.result()
                if chunk is None:
                    break
                self._last_output = time.monotonic()
                for line in splitter.feed(chunk):
                    self._write(line)
                self._partial = splitter.partial
                self._show_partial()
                job.seconds = time.monotonic() - started
                continue
            # Process exited. A backgrounded grandchild may keep the pty open,
            # so drain briefly instead of waiting for EOF forever.
            try:
                chunk = await asyncio.wait_for(reader, 0.5)
                while chunk is not None:
                    for line in splitter.feed(chunk):
                        self._write(line)
                    chunk = await asyncio.wait_for(self.proc.read(), 0.5)
            except asyncio.TimeoutError:
                reader.cancel()
            break

        for line in splitter.flush():
            self._write(line)
        job.returncode = await waiter
        self.proc.close()
        self.proc = None
        self._partial = ""
        self._show_partial()
        self._hide_reply()
        job.seconds = time.monotonic() - started
        if job.returncode == 0:
            job.state = "ok"
        else:
            job.state = "failed"
            self._write(f"✗ {job.module.name} exited with {job.returncode}", "err")
        self._refresh_job(job)

    def _tick(self) -> None:
        for job in self.jobs:
            if job.state == "running" and self.proc is not None:
                self._refresh_job(job)
        if (
            self.proc is not None
            and self._partial
            and time.monotonic() - self._last_output >= PROMPT_IDLE_SECONDS
            and looks_like_prompt(self._partial)
        ):
            self._show_reply(password=looks_like_password(self._partial))

    def _show_partial(self) -> None:
        live = self.query_one("#live", Static)
        live.update(Text.from_ansi(self._partial) if self._partial else "")
        live.display = bool(self._partial)

    def _show_reply(self, password: bool) -> None:
        reply = self.query_one("#reply", Input)
        reply.password = password
        reply.placeholder = "sent to the installer, never logged" if password else "type a reply and press enter"
        reply.border_title = "password" if password else "installer is waiting for input"
        if not reply.has_class("waiting"):
            reply.add_class("waiting")
            reply.focus()

    def _hide_reply(self) -> None:
        reply = self.query_one("#reply", Input)
        reply.remove_class("waiting")
        reply.value = ""
        reply.password = False

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id != "reply" or self.proc is None:
            return
        value = event.value
        event.input.value = ""
        self.proc.write(value + "\n")
        # The prompt line itself arrives from the pty once the child prints
        # its newline; mark it there instead of echoing anything here.
        self._masked_prompt = strip_ansi(self._partial) if event.input.password else None
        self._hide_reply()

    # buttons ------------------------------------------------------------

    def _set_buttons(self) -> None:
        failed = any(j.state == "failed" for j in self.jobs)
        self.query_one("#abort", Button).disabled = not self.running
        self.query_one("#retry", Button).disabled = self.running or not failed
        self.query_one("#done", Button).disabled = self.running

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "abort":
            self.action_abort()
        elif event.button.id == "retry":
            self.action_retry()
        elif event.button.id == "done":
            self._finish()

    def check_action(self, action: str, parameters: tuple[object, ...]) -> bool | None:
        if action == "abort":
            return self.running
        if action == "back":
            return not self.running
        if action == "retry":
            return not self.running and any(j.state == "failed" for j in self.jobs)
        return True

    def action_back(self) -> None:
        self._finish()

    def action_abort(self) -> None:
        if not self.running:
            self._finish()
            return
        if self.aborting:
            return

        def confirmed(ok: bool | None) -> None:
            if ok and self.running:
                self.aborting = True
                self._write("Aborting: stopping current step, skipping the rest…", "warn")
                if self.proc is not None:
                    asyncio.ensure_future(self.proc.terminate())

        self.app.push_screen(
            ConfirmScreen(Plan("abort", [j.module for j in self.jobs if j.state == "running"])),
            confirmed,
        )

    def action_retry(self) -> None:
        if self.running:
            return
        failed = [j for j in self.jobs if j.state == "failed"]
        if not failed:
            return
        for job in failed:
            job.state = "pending"
            self._refresh_job(job)
        self._update_summary()
        self.start(failed)

    def action_focus_log(self) -> None:
        self.query_one("#log", RichLog).focus()

    def _finish(self) -> None:
        if self.running:
            return
        if self._log_file:
            self._log_file.close()
            self._log_file = None
        self.dismiss(RunResult(self.action, self.jobs, self.log_path, self.aborted))

    def on_unmount(self) -> None:
        if self.proc is not None:
            self.proc.signal_group(signal.SIGTERM)
            self.proc.close()
        if self._log_file:
            self._log_file.close()

