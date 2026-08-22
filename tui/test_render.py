from textual.pilot import Pilot
from tui.app import AllConfigsApp


async def test_app():
    app = AllConfigsApp()
    async with app.run_test() as pilot:
        pilot: Pilot
        await pilot.pause()
        svg = app.export_screenshot()
        with open("/tmp/tui_initial.svg", "w") as f:
            f.write(svg)
        print("saved /tmp/tui_initial.svg")
        # Wait for splash to disappear
        for _ in range(20):
            await pilot.pause(0.1)
        svg2 = app.export_screenshot()
        with open("/tmp/tui_after.svg", "w") as f:
            f.write(svg2)
        print("saved /tmp/tui_after.svg")


if __name__ == "__main__":
    import asyncio
    asyncio.run(test_app())
