from __future__ import annotations

from textual import events
from textual.binding import Binding
from textual.widgets import DataTable, Input


class ModuleTable(DataTable):
    """Module list. Space toggles, enter installs, up on the first row jumps to search."""

    BINDINGS = [
        Binding("space", "screen.toggle", "Select"),
        Binding("enter", "screen.install", "Install"),
    ]

    def __init__(self, **kwargs) -> None:
        super().__init__(cursor_type="row", cursor_foreground_priority="renderable", **kwargs)

    def on_key(self, event: events.Key) -> None:
        if event.key == "up" and self.cursor_row == 0:
            self.screen.query_one("#search", Input).focus()
            event.stop()
