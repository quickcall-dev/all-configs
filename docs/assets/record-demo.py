"""Record docs/assets/demo.gif frames from the real TUI, headless.

Real module.toml files and real detection; every install.sh is replaced by a fake
that only echoes, so nothing is installed. Usage (from the repo root):

    ALL_CONFIGS_THEME=dark PYTHONPATH=. uv run --no-project --python 3.12 \
        --with 'textual==8.2.*' python docs/assets/record-demo.py /tmp/demo-frames
    cd /tmp/demo-frames && qlmanage -t -s 1600 -o . *.svg      # SVG -> PNG (macOS)

Then stitch the PNGs listed in frames.txt (name<TAB>seconds) with ffmpeg:
crop=1600:898:0:351, scale=1280, palettegen stats_mode=full, paletteuse.
"""
import asyncio, os, shutil, sys, textwrap
from pathlib import Path
from allconfigs.tui.app import AllConfigsApp
from allconfigs.tui.screens import RunScreen, ConfirmScreen

REPO = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]); ROOT = OUT / "root"
SIZE = (120, 32)

FAKE = {
    "tmux": ["Installing tmux", "✓ tmux 3.5a already installed", "Cloning oh-my-tmux…", "✓ ~/.tmux.conf → oh-my-tmux", "✓ ~/.tmux.conf.local linked", "Done"],
    "nvim": ["Installing Neovim", "==> Fetching neovim", "✓ nvim 0.11.4", "✓ ~/.config/nvim linked", "Syncing plugins (lazy.nvim)…", "Done"],
    "ffmpeg": ["Installing ffmpeg", "==> Fetching ffmpeg", "==> Pouring ffmpeg--8.0.arm64_sequoia.bottle.tar.gz", "✓ ffmpeg 8.0", "Done"],
}

def build_root():
    shutil.rmtree(ROOT, ignore_errors=True)
    (ROOT / "lib").mkdir(parents=True)
    for toml in sorted((REPO / "modules").glob("*/module.toml")):
        d = ROOT / "modules" / toml.parent.name
        d.mkdir(parents=True)
        shutil.copy(toml, d / "module.toml")
        lines = FAKE.get(d.name, [f"Installing {d.name}", "Done"])
        body = "".join(f'echo "{l}"; sleep 0.35\n' for l in lines)
        (d / "install.sh").write_text("#!/usr/bin/env bash\n" + body)

frames = []
async def snap(app, name, hold):
    p = OUT / f"{len(frames):03d}-{name}.svg"
    p.write_text(app.export_screenshot())
    frames.append((p, hold))

async def typing(pilot, app, text, name):
    for ch in text:
        await pilot.press(ch); await pilot.pause(0.05)
        await snap(app, name, 0.12)

async def main():
    build_root()
    app = AllConfigsApp(root=ROOT)
    async with app.run_test(size=SIZE) as pilot:
        for _ in range(60):
            await pilot.pause(0.2)
            if not any(m.status.value == "checking" for m in app.modules): break
        await snap(app, "main", 2.2)
        for _ in range(4):
            await pilot.press("down"); await pilot.pause(0.05); await snap(app, "nav", 0.25)
        await pilot.press("slash"); await pilot.pause(0.1); await snap(app, "search", 0.4)
        await typing(pilot, app, "tmux", "search")
        await pilot.press("enter", "space"); await pilot.pause(0.1); await snap(app, "pick", 0.9)
        await pilot.press("escape"); await pilot.pause(0.1)
        await pilot.press("slash"); await typing(pilot, app, "nvim", "search")
        await pilot.press("enter", "space"); await pilot.pause(0.1); await snap(app, "pick", 0.8)
        await pilot.press("escape", "slash"); await typing(pilot, app, "ffmpeg", "search")
        await pilot.press("enter", "space"); await pilot.pause(0.1); await snap(app, "pick", 0.8)
        await pilot.press("escape"); await pilot.pause(0.1); await snap(app, "selected", 1.6)
        await pilot.press("enter"); await pilot.pause(0.3); await snap(app, "confirm", 2.0)
        await pilot.press("y"); await pilot.pause(0.2)
        while isinstance(app.screen, RunScreen) and app.screen.running:
            await snap(app, "run", 0.35); await pilot.pause(0.35)
        await pilot.pause(0.2); await snap(app, "done", 2.4)
        await pilot.press("escape")
        for _ in range(40):
            await pilot.pause(0.2)
            if not any(m.status.value == "checking" for m in app.modules): break
        await pilot.pause(0.6); await snap(app, "after", 2.8)
    (OUT / "frames.txt").write_text("".join(f"{p.name}\t{h}\n" for p, h in frames))

asyncio.run(main())
