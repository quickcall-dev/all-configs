"""Textual TUI for the all-configs installer."""

from __future__ import annotations

import subprocess
from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Footer, Header, Label, Log, SelectionList, Static
from textual.widgets.selection_list import Selection

from all_configs.modules import discover_modules


class InstallerApp(App[None]):
    """Interactive installer for all-configs modules."""

    CSS = """
    Screen { align: center middle; }
    #main { width: 100%; height: 100%; padding: 2 4; }
    #title {
        text-align: center;
        text-style: bold;
        color: $text-accent;
        margin-bottom: 1;
    }
    #split { height: 55%; border: solid $primary; }
    #modules { width: 60%; border: solid $primary; }
    #preview {
        width: 40%;
        border: solid $surface-lighten-1;
        padding: 1 2;
        color: $text-muted;
    }
    #install { margin-top: 1; width: 100%; }
    #log { height: 35%; border: solid $surface-lighten-1; margin-top: 1; }
    #status { height: auto; margin-top: 1; text-style: bold; }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("a", "select_all", "Select all"),
        ("n", "select_none", "Select none"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._init_error: str | None = None
        try:
            self.modules = discover_modules()
        except Exception as exc:
            self.modules = []
            self._init_error = str(exc)
        self.log_widget: Log | None = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)
        with Vertical(id="main"):
            yield Static("all-configs installer", id="title")
            selections = [
                Selection(f"{m['name']}  —  {m['description']}", m["name"], True)
                for m in self.modules
            ]
            with Horizontal(id="split"):
                yield SelectionList(*selections, id="modules")
                yield Static(
                    "Select a module to see details.",
                    id="preview",
                )
            yield Button("Install selected", id="install", variant="primary")
            yield Log(id="log")
            yield Label("Ready", id="status")
        yield Footer()

    def on_mount(self) -> None:
        self.log_widget = self.query_one("#log", Log)
        module_list = self.query_one("#modules", SelectionList)
        module_list.border_title = "Modules (Space to toggle)"
        preview = self.query_one("#preview", Static)
        preview.border_title = "Preview"
        if self.modules:
            module_list.highlighted = 0
            self._update_preview(self.modules[0]["name"])
        if self._init_error:
            self.set_status(f"Error loading modules: {self._init_error}")

    def _update_preview(self, name: str) -> None:
        for module in self.modules:
            if module["name"] == name:
                lines = [
                    f"[b]Name:[/b] {module['name']}",
                    f"[b]Description:[/b] {module['description']}",
                    f"[b]Platforms:[/b] {', '.join(module['platforms'])}",
                    f"[b]Path:[/b] {module['path']}",
                ]
                self.query_one("#preview", Static).update("\n".join(lines))
                return

    def on_selection_list_selected_changed(self, event: SelectionList.SelectedChanged) -> None:
        self._update_preview(event.item_id)

    def action_select_all(self) -> None:
        module_list = self.query_one("#modules", SelectionList)
        module_list.select_all()

    def action_select_none(self) -> None:
        module_list = self.query_one("#modules", SelectionList)
        module_list.clear_selections()

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id != "install":
            return
        await self.run_install()

    async def run_install(self) -> None:
        module_list = self.query_one("#modules", SelectionList)
        selected = set(module_list.selected)
        if not selected:
            self.set_status("No modules selected")
            return

        button = self.query_one("#install", Button)
        button.disabled = True
        self.clear_log()
        self.log_line(f"Installing: {', '.join(sorted(selected))}\n")

        failed: list[str] = []
        for module in self.modules:
            name = module["name"]
            if name not in selected:
                continue
            install_script = module["path"] / "install.sh"
            self.log_line(f"→ {name} ...")
            self.set_status(f"Installing {name} ...")
            try:
                proc = subprocess.run(
                    ["bash", str(install_script)],
                    cwd=module["path"],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                if proc.stdout:
                    self.log_line(proc.stdout)
                self.log_line(f"✓ {name} done\n")
            except subprocess.CalledProcessError as exc:
                failed.append(name)
                self.log_line(exc.stdout or "")
                self.log_line(exc.stderr or "")
                self.log_line(f"✗ {name} failed\n")

        button.disabled = False
        if failed:
            self.set_status(f"Finished with failures: {', '.join(failed)}")
        else:
            self.set_status("All selected modules installed")

    def log_line(self, text: str) -> None:
        if self.log_widget:
            self.log_widget.write(text)

    def clear_log(self) -> None:
        if self.log_widget:
            self.log_widget.clear()

    def set_status(self, text: str) -> None:
        self.query_one("#status", Label).update(text)


def main() -> None:
    InstallerApp().run()
