from __future__ import annotations

from textual import events
from textual.binding import Binding
from textual.widgets import DataTable, Input


class ModuleTable(DataTable):
    """Module list that toggles selection with space and moves focus up to search."""

    BINDINGS = [
        Binding("enter", "install", "Install"),
    ]

    def on_mount(self) -> None:
        self.add_column("", key="selected", width=3)
        self.add_column("Module", key="module", width=15)
        self.add_column("Description", key="description")
        self.add_column("Status", key="status", width=12)
        self.add_column("Platforms", key="platforms", width=11)

    def on_key(self, event: events.Key) -> None:
        if event.key == "space":
            self.app.action_toggle()
            event.stop()
        elif event.key == "up" and self.cursor_row == 0:
            self.app.screen.query_one("#search", Input).focus()
            event.stop()

    def action_install(self) -> None:
        """Trigger install from the module table."""
        self.app.action_install()
