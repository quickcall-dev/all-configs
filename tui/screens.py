from __future__ import annotations

import asyncio
from dataclasses import dataclass
from pathlib import Path

import pyfiglet
from rich.text import Text
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.screen import ModalScreen, Screen
from textual.widgets import Button, Input, ProgressBar, RichLog, Static

from tui.widgets import ModuleTable


@dataclass(frozen=True)
class Module:
    name: str
    description: str
    platforms: list[str]


KEYS_TEXT = """
space    toggle selected module
a        select all visible
n        select none
i        invert selection
enter    install selected
?        show this help
q        quit
""".strip()


_HEADER_FIG = pyfiglet.Figlet(font="rectangles")
_SPLASH_FIG = pyfiglet.Figlet(font="rectangles")


def _fig_text(fig: pyfiglet.Figlet, text: str, style: str) -> Text:
    rendered = fig.renderText(text)
    lines = [line.rstrip() for line in rendered.splitlines()]
    while lines and lines[0] == "":
        lines.pop(0)
    while lines and lines[-1] == "":
        lines.pop()
    return Text("\n".join(lines), style=style)


class MainScreen(Screen):
    """Single-screen module selector with a splash overlay."""

    def compose(self) -> ComposeResult:
        with Vertical(id="main"):
            with Container(id="header"):
                yield Static(_fig_text(_HEADER_FIG, "all-configs", "bold #60a5fa"), id="header-title")
                yield Static("installer", id="header-subtitle")
            yield Input(placeholder="search modules...", id="search")
            yield ModuleTable(id="module-table")
            yield Static("", id="footer")
            with Container(id="splash-overlay"):
                with Container(id="splash"):
                    yield Static(_fig_text(_SPLASH_FIG, "all-configs", "bold #2563eb"), id="splash-title")
                    yield Static("installer", id="splash-subtitle")
                    yield ProgressBar(total=100, id="splash-progress")

    def on_mount(self) -> None:
        self.query_one("#search", Input).focus()
        table = self.query_one("#module-table", ModuleTable)
        footer = self.query_one("#footer", Static)
        self.app.refresh_table(table)
        self.app.update_footer(footer)
        self._progress = 0
        self._bar = self.query_one("#splash-progress", ProgressBar)
        self._splash_timer = self.set_interval(0.05, self._advance_splash)

    def _advance_splash(self) -> None:
        self._progress += 6
        if self._progress >= 100:
            self._bar.update(progress=100)
            self._splash_timer.stop()
            self.query_one("#splash-overlay", Container).remove()
        else:
            self._bar.update(progress=self._progress)


class HelpScreen(ModalScreen):
    """Keybindings help."""

    BINDINGS = [Binding("escape", "dismiss", "")]

    def compose(self) -> ComposeResult:
        with Container(id="help"):
            yield Static(KEYS_TEXT, id="help-text")
            yield Button("Close", id="close")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss()


class ConfirmScreen(ModalScreen[bool]):
    """Confirm before installing."""

    BINDINGS = [Binding("escape", "dismiss", "")]

    def __init__(self, modules: list[str]) -> None:
        self.modules = modules
        super().__init__()

    def compose(self) -> ComposeResult:
        with Container(id="confirm"):
            yield Static(f"Install {len(self.modules)} module(s)?", id="confirm-title")
            yield Static("\n".join(self.modules), id="confirm-list")
            with Horizontal(id="confirm-buttons"):
                yield Button("Install", id="install", variant="primary")
                yield Button("Cancel", id="cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "install")


class InstallScreen(ModalScreen[list[str]]):
    """Run selected installers and show output."""

    BINDINGS = [Binding("escape", "dismiss", "")]

    def __init__(self, modules: list[Module], root: Path) -> None:
        self.modules = modules
        self.root = root
        self.failed: list[str] = []
        super().__init__()

    def compose(self) -> ComposeResult:
        with Container(id="install"):
            yield Static(f"Installing {len(self.modules)} module(s)", id="install-title")
            yield RichLog(id="install-log")
            yield Button("Close", id="close", disabled=True)

    def on_mount(self) -> None:
        asyncio.create_task(self._run_installs())

    async def _run_installs(self) -> None:
        log = self.query_one("#install-log", RichLog)
        for module in self.modules:
            log.write(f"-> {module.name}")
            proc = await asyncio.create_subprocess_exec(
                "bash",
                str(self.root / module.name / "install.sh"),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                log.write(line.decode("utf-8", errors="replace").rstrip())
            await proc.wait()
            if proc.returncode != 0:
                self.failed.append(module.name)
                log.write(f"FAILED {module.name}")
            else:
                log.write(f"done {module.name}")
        log.write(f"\nFinished. {len(self.failed)} failed.")
        close = self.query_one("#close", Button)
        close.disabled = False
        close.focus()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(self.failed)
