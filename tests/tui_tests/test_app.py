from __future__ import annotations

import asyncio

from textual.widgets import Input

from tui.app import AllConfigsApp
from tui.modules import Status
from tui.screens import ConfirmScreen, MainScreen, RunScreen
from tui.widgets import ModuleTable


async def settle(pilot, until, timeout=10.0):
    loop = asyncio.get_running_loop()
    end = loop.time() + timeout
    while not until():
        assert loop.time() < end, "timed out"
        await pilot.pause(0.05)


def app_for(root, probe):
    return AllConfigsApp(root=root, probe=probe)


async def goto(pilot, app, name):
    table = app.screen.query_one(ModuleTable)
    table.focus()
    names = list(table.rows)
    table.move_cursor(row=[k.value for k in names].index(name))
    await pilot.pause()


async def run_and_wait(pilot, app):
    await settle(pilot, lambda: isinstance(app.screen, RunScreen))
    await settle(pilot, lambda: not app.screen.running)
    return app.screen


async def test_startup_lists_and_detects(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await settle(pilot, lambda: all(m.status is not Status.CHECKING for m in app.modules))
        assert isinstance(app.screen, MainScreen)
        table = app.screen.query_one(ModuleTable)
        assert table.row_count == 6
        assert app.module_by_name["okmod"].status is Status.MISSING
        assert app.load_errors  # broken module reported, not fatal


async def test_search_filters_and_keeps_selection(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "okmod")
        await pilot.press("space")
        assert app.selected == {"okmod"}
        await pilot.press("slash")
        await pilot.press(*"fail")
        assert app.screen.query_one(ModuleTable).row_count == 1
        await pilot.press("escape")  # clears search, back to table
        assert app.screen.query_one("#search", Input).value == ""
        assert app.screen.query_one(ModuleTable).row_count == 6
        assert app.selected == {"okmod"}


async def test_install_success_rescans(root, probe, home):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "okmod")
        await pilot.press("space", "enter")
        assert isinstance(app.screen, ConfirmScreen)
        await pilot.press("y")
        screen = await run_and_wait(pilot, app)
        assert [j.state for j in screen.jobs] == ["ok"]
        assert screen.log_path and "hello from okmod" in screen.log_path.read_text()
        await pilot.click("#done")
        await settle(pilot, lambda: app.module_by_name["okmod"].status is Status.INSTALLED)
        assert app.selected == set()


async def test_failure_and_retry(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "failmod")
        await pilot.press("enter", "y")  # nothing selected -> cursor module
        screen = await run_and_wait(pilot, app)
        assert screen.jobs[0].state == "failed" and screen.jobs[0].returncode == 3
        assert not screen.query_one("#retry").disabled
        await pilot.press("ctrl+r")
        await settle(pilot, lambda: not screen.running and screen.jobs[0].state == "failed")
        await pilot.click("#done")
        await pilot.pause()
        assert app.had_failures
        assert app.module_by_name["failmod"].last_run_failed


async def test_prompt_is_answered_through_reply_box(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "askmod")
        await pilot.press("enter", "y")
        await settle(pilot, lambda: isinstance(app.screen, RunScreen))
        screen = app.screen
        reply = screen.query_one("#reply", Input)
        await settle(pilot, lambda: reply.has_class("waiting"))
        assert not reply.password
        await pilot.press(*"sagar", "enter")
        await settle(pilot, lambda: not screen.running)
        assert screen.jobs[0].state == "ok"
        assert "hi sagar" in screen.log_path.read_text()


async def test_abort_kills_running_step_and_skips_rest(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        for name in ("slowmod", "okmod"):
            await goto(pilot, app, name)
            await pilot.press("space")
        await pilot.press("enter", "y")
        await settle(pilot, lambda: isinstance(app.screen, RunScreen))
        screen = app.screen
        await settle(pilot, lambda: screen.jobs[0].state == "running" or screen.jobs[1].state == "running")
        await pilot.press("escape")
        await settle(pilot, lambda: isinstance(app.screen, ConfirmScreen))
        await pilot.press("y")
        await settle(pilot, lambda: not screen.running, timeout=15)
        states = {j.module.name: j.state for j in screen.jobs}
        assert states["slowmod"] == "failed"
        assert screen.aborted


async def test_escape_during_run_never_dismisses(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "slowmod")
        await pilot.press("enter", "y")
        await settle(pilot, lambda: isinstance(app.screen, RunScreen))
        screen = app.screen
        await pilot.press("escape")
        await settle(pilot, lambda: isinstance(app.screen, ConfirmScreen))
        await pilot.press("escape")  # cancel abort
        await pilot.pause()
        assert app.screen is screen and screen.running
        screen.aborting = True
        await screen.proc.terminate(grace=1)
        await settle(pilot, lambda: not screen.running)


async def test_uninstall_skips_config_modules(root, probe, home):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        for name in ("okmod", "cfgmod"):
            await goto(pilot, app, name)
            await pilot.press("space")
        await pilot.press("u")
        assert isinstance(app.screen, ConfirmScreen)
        assert [m.name for m in app.screen.plan.run] == ["okmod"]
        await pilot.press("y")
        screen = await run_and_wait(pilot, app)
        assert screen.jobs[0].state == "ok"
        assert (home / "uninstalled").read_text().strip() == "okpkg"


async def test_uninstall_only_config_is_refused(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "cfgmod")
        await pilot.press("u")
        await pilot.pause()
        assert isinstance(app.screen, MainScreen)


async def test_password_prompt_is_masked_and_not_logged(root, probe):
    app = app_for(root, probe)
    async with app.run_test(size=(120, 40)) as pilot:
        await goto(pilot, app, "pwmod")
        await pilot.press("enter", "y")
        await settle(pilot, lambda: isinstance(app.screen, RunScreen))
        screen = app.screen
        reply = screen.query_one("#reply", Input)
        await settle(pilot, lambda: reply.has_class("waiting"))
        assert reply.password
        await pilot.press(*"hunter2", "enter")
        await settle(pilot, lambda: not screen.running)
        assert screen.jobs[0].state == "ok"
        log = screen.log_path.read_text()
        assert "auth ok" in log and "hunter2" not in log
