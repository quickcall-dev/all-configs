from __future__ import annotations

import sys
import tomllib
from pathlib import Path

from rich.text import Text
from textual import events
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.coordinate import Coordinate
from textual.widgets import Input, Static

from tui.screens import (
    ConfirmScreen,
    HelpScreen,
    InstallScreen,
    MainScreen,
    Module,
)
from tui.widgets import ModuleTable

PLATFORM = "mac" if sys.platform == "darwin" else "linux"


def load_modules(root: Path) -> list[Module]:
    """Discover modules from module.toml files for the current platform."""
    modules: list[Module] = []
    for toml_path in root.glob("*/module.toml"):
        with open(toml_path, "rb") as f:
            data = tomllib.load(f)
        name = data.get("name", toml_path.parent.name)
        description = data.get("description", "")
        platforms = data.get("platforms", ["mac", "linux"])
        if PLATFORM not in platforms:
            continue
        modules.append(Module(name=name, description=description, platforms=platforms))
    return modules


class AllConfigsApp(App):
    """Textual TUI for all-configs."""

    CSS_PATH = "styles.tcss"
    TITLE = "all-configs installer"
    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("ctrl+q", "force_quit", "Quit"),
        Binding("ctrl+c", "force_quit", "Quit"),
        Binding("a", "select_all", "Select All"),
        Binding("n", "select_none", "Select None"),
        Binding("i", "invert", "Invert"),
        Binding("enter", "install", "Install"),
        Binding("?", "help", "Help"),
    ]

    def __init__(self, root: Path | None = None) -> None:
        super().__init__()
        self.dark = False
        self.root = root or Path(__file__).resolve().parent.parent
        self.modules: list[Module] = []
        self.visible_modules: list[Module] = []
        self.selected: set[str] = set()
        self.filter_text: str = ""
        self.failed_modules: list[str] = []

    def _typing_in_search(self) -> bool:
        return isinstance(self.focused, Input)

    def _on_main_screen(self) -> bool:
        return isinstance(self.screen, MainScreen)

    def on_mount(self) -> None:
        self.modules = load_modules(self.root)
        self.modules.sort(key=lambda m: m.name)
        self.visible_modules = self.modules[:]
        self.push_screen(MainScreen())

    def on_key(self, event: events.Key) -> None:
        if event.key == "down" and self._on_main_screen() and self._typing_in_search():
            self.screen.query_one("#module-table", ModuleTable).focus()
            event.stop()

    def _checkbox(self, name: str) -> Text:
        if name in self.selected:
            return Text("[x]", style="bold #2563eb")
        return Text("[ ]", style="#9ca3af")

    def refresh_table(self, table: ModuleTable | None = None) -> None:
        if table is None:
            table = self.screen.query_one("#module-table", ModuleTable)
        table.clear(columns=False)
        self.visible_modules = [
            m
            for m in self.modules
            if (
                self.filter_text in m.name.lower()
                or self.filter_text in m.description.lower()
                or self.filter_text in " ".join(m.platforms).lower()
            )
        ]
        for module in self.visible_modules:
            table.add_row(
                self._checkbox(module.name),
                module.name,
                module.description,
                ", ".join(module.platforms),
                key=module.name,
            )

    def update_footer(self, footer: Static | None = None) -> None:
        if footer is None:
            footer = self.screen.query_one("#footer", Static)
        footer.update(
            " | ".join(
                [
                    f"selected: {len(self.selected)}",
                    "space toggle",
                    "a all",
                    "n none",
                    "i invert",
                    "enter install",
                    "? help",
                    "q quit",
                ]
            )
        )

    def on_input_changed(self, event: Input.Changed) -> None:
        if not self._on_main_screen():
            return
        self.filter_text = event.value.lower()
        self.refresh_table()

    def action_toggle(self) -> None:
        if not self._on_main_screen():
            return
        table = self.screen.query_one("#module-table", ModuleTable)
        if not table.has_focus or table.cursor_row < 0 or table.cursor_row >= len(self.visible_modules):
            return
        module = self.visible_modules[table.cursor_row]
        if module.name in self.selected:
            self.selected.remove(module.name)
        else:
            self.selected.add(module.name)
        table.update_cell_at(Coordinate(table.cursor_row, 0), self._checkbox(module.name))
        self.update_footer()

    def _select_all(self, value: bool) -> None:
        for module in self.visible_modules:
            if value:
                self.selected.add(module.name)
            else:
                self.selected.discard(module.name)
        table = self.screen.query_one("#module-table", ModuleTable)
        for i, module in enumerate(self.visible_modules):
            table.update_cell_at(Coordinate(i, 0), self._checkbox(module.name))
        self.update_footer()

    def action_select_all(self) -> None:
        if not self._on_main_screen() or self._typing_in_search():
            return
        self._select_all(True)

    def action_select_none(self) -> None:
        if not self._on_main_screen() or self._typing_in_search():
            return
        self._select_all(False)

    def action_invert(self) -> None:
        if not self._on_main_screen() or self._typing_in_search():
            return
        for module in self.visible_modules:
            if module.name in self.selected:
                self.selected.remove(module.name)
            else:
                self.selected.add(module.name)
        table = self.screen.query_one("#module-table", ModuleTable)
        for i, module in enumerate(self.visible_modules):
            table.update_cell_at(Coordinate(i, 0), self._checkbox(module.name))
        self.update_footer()

    def action_install(self) -> None:
        if not self._on_main_screen() or self._typing_in_search() or not self.selected:
            return
        self.push_screen(ConfirmScreen(sorted(self.selected)), callback=self._on_confirm)

    def action_help(self) -> None:
        if not self._on_main_screen() or self._typing_in_search():
            return
        self.push_screen(HelpScreen())

    def _on_confirm(self, confirmed: bool) -> None:
        if not confirmed:
            return
        selected_modules = [m for m in self.modules if m.name in self.selected]
        self.push_screen(InstallScreen(selected_modules, self.root), callback=self._on_install_done)

    def _on_install_done(self, failed: list[str]) -> None:
        self.failed_modules = failed
        if failed:
            self.notify(f"Finished with {len(failed)} failures", title="Done", severity="error")
        else:
            self.notify("All modules installed", title="Done", severity="information")

    def action_help(self) -> None:
        if self._typing_in_search():
            return
        self.push_screen(HelpScreen())

    def action_quit(self) -> None:
        if self._typing_in_search():
            return
        self.exit(1 if self.failed_modules else 0)

    def action_force_quit(self) -> None:
        self.exit(1 if self.failed_modules else 0)
