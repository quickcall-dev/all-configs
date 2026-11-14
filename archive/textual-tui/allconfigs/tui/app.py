from __future__ import annotations

import asyncio
import os
from collections.abc import Callable
from pathlib import Path

from textual import work
from textual.app import App
from textual.binding import Binding

from allconfigs.modules import Environment, Module, Status, detect, load_modules, probe_environment
from allconfigs.tui.screens import ConfirmScreen, Job, MainScreen, Plan, RunResult, RunScreen
from allconfigs.tui.theme import DARK, LIGHT, THEMES

DEFAULT_THEME = LIGHT.name


class AllConfigsApp(App[int]):
    """Textual TUI for all-configs (macOS and Linux)."""

    CSS_PATH = "styles.tcss"
    TITLE = "all-configs"
    BINDINGS = [
        Binding("ctrl+c", "quit", "Quit", show=False, priority=True),
        Binding("ctrl+q", "quit", "Quit", show=False, priority=True),
    ]

    def __init__(
        self,
        root: Path | None = None,
        probe: Callable[[], Environment] = probe_environment,
    ) -> None:
        super().__init__()
        self.root = root or Path(__file__).resolve().parents[2]
        self.probe = probe
        self.modules: list[Module] = []
        self.module_by_name: dict[str, Module] = {}
        self.selected: set[str] = set()
        self.load_errors: list[str] = []
        self.had_failures = False
        self.environment: Environment | None = None

    # lifecycle ----------------------------------------------------------

    def on_mount(self) -> None:
        for custom in THEMES:
            self.register_theme(custom)
        theme = os.environ.get("ALL_CONFIGS_THEME", DEFAULT_THEME)
        theme = {"light": LIGHT.name, "dark": DARK.name}.get(theme, theme)
        if theme in self.available_themes:
            self.theme = theme
        self.modules, self.load_errors = load_modules(self.root)
        self.module_by_name = {m.name: m for m in self.modules}
        self.push_screen(MainScreen())
        for error in self.load_errors:
            self.notify(error, title="Skipped module", severity="warning", timeout=10)
        # wait until MainScreen has composed its table before touching it
        self.call_after_refresh(self.rescan)

    @property
    def main(self) -> MainScreen | None:
        for screen in self.screen_stack:
            if isinstance(screen, MainScreen):
                return screen
        return None

    # detection ----------------------------------------------------------

    def rescan(self, modules: list[Module] | None = None) -> None:
        targets = modules if modules is not None else self.modules
        for module in targets:
            module.status = Status.CHECKING
        if self.main:
            for module in targets:
                self.main.refresh_module(module)
            self.main.update_bars()
        self._detect(targets)

    @work(exclusive=True, group="detect")
    async def _detect(self, modules: list[Module]) -> None:
        self.environment = await asyncio.to_thread(self.probe)
        for module in modules:
            module.status = await asyncio.to_thread(detect, module, self.environment)
            if self.main:
                self.main.refresh_module(module)
        if self.main:
            self.main.update_bars()

    # install / uninstall -------------------------------------------------

    def request_install(self, modules: list[Module]) -> None:
        plan = Plan("install", modules)
        self.push_screen(ConfirmScreen(plan), lambda ok: ok and self._run(plan))

    def request_uninstall(self, modules: list[Module]) -> None:
        allowed = [m for m in modules if m.can_uninstall]
        blocked = [m.name for m in modules if not m.can_uninstall]
        notes = []
        if blocked:
            notes.append(("Skipped (config modules or no package to remove):", blocked))
        if not allowed:
            self.notify(
                "Nothing to uninstall: " + ", ".join(blocked),
                title="Uninstall not available",
                severity="warning",
            )
            return
        plan = Plan("uninstall", allowed, notes)
        self.push_screen(ConfirmScreen(plan), lambda ok: ok and self._run(plan))

    def _job(self, action: str, module: Module) -> Job:
        if action == "install":
            argv = ["bash", str(module.install_script)]
        else:
            argv = ["bash", str(self.root / "lib" / "uninstall.sh"), *module.uninstall_packages]
        return Job(module, argv)

    def _run(self, plan: Plan) -> None:
        jobs = [self._job(plan.action, m) for m in plan.run]
        self.push_screen(RunScreen(plan.action, jobs, self.root), self._on_run_done)

    def _on_run_done(self, result: RunResult | None) -> None:
        if result is None:
            return
        failed = {j.module.name for j in result.failed}
        self.had_failures = bool(failed)
        touched = []
        for job in result.jobs:
            job.module.last_run_failed = job.module.name in failed
            if job.state in ("ok", "failed"):
                touched.append(job.module)
        self.selected.difference_update(j.module.name for j in result.jobs if j.state == "ok")
        if self.main:
            self.main.refresh_rows()
        self.rescan(touched)
        if result.aborted:
            self.notify("Run aborted", severity="warning")
        elif failed:
            self.notify(f"{len(failed)} failed: {', '.join(sorted(failed))}", title="Done", severity="error")
        else:
            self.notify(f"{result.action.capitalize()} finished", title="Done")

    # quit ----------------------------------------------------------------

    def action_quit(self) -> None:
        if isinstance(self.screen, RunScreen) and self.screen.running:
            self.screen.action_abort()
            return
        self.exit(1 if self.had_failures else 0)
