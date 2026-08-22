import asyncio
from textual.pilot import Pilot
from tui.app import AllConfigsApp
from tui.screens import ConfirmScreen


async def _wait_for_splash(pilot: Pilot) -> None:
    for _ in range(30):
        await pilot.pause(0.1)


async def _navigate_to_module(app: AllConfigsApp, pilot: Pilot, target: str) -> bool:
    table = app.screen.query_one("#module-table")
    for _ in range(len(table.rows)):
        if table.get_row_at(table.cursor_row)[1] == target:
            return True
        await pilot.press("down")
    return False


async def test_enter_install():
    app = AllConfigsApp()
    async with app.run_test() as pilot:
        pilot: Pilot
        await _wait_for_splash(pilot)

        # Move focus to module table and select a not-installed module.
        await pilot.press("tab")
        target = "ncdu"
        if not await _navigate_to_module(app, pilot, target):
            raise RuntimeError(f"module {target} not found in TUI")
        await pilot.press("space")
        assert app.selected == {target}, f"expected {target} selected, got {app.selected}"

        # Press Enter in the table.
        await pilot.press("enter")
        assert any(isinstance(s, ConfirmScreen) for s in app.screen_stack), \
            "ConfirmScreen not opened from table Enter"
        app.pop_screen()
        await pilot.pause()

        # Move focus back to search and press Enter again.
        await pilot.press("tab")
        await pilot.press("enter")
        assert any(isinstance(s, ConfirmScreen) for s in app.screen_stack), \
            "ConfirmScreen not opened from search Enter"


if __name__ == "__main__":
    asyncio.run(test_enter_install())
    print("enter-install tests passed")
