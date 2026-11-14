#!/usr/bin/env python3
"""Capture screenshots of the OpenTUI all-configs app running inside tmux.

Drives the real app with real detection, captures colored frames via
`tmux capture-pane -e`, and renders them to PNG with Pillow.
"""

import re
import subprocess
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SESSION = "acshot"
COLS, ROWS = 118, 33
OUT = Path("/Users/sagar/all-configs/docs/experiments/003-opentui-tui/screenshots")
OUT.mkdir(parents=True, exist_ok=True)

# ─── ANSI parsing ───────────────────────────────────────────────────────────

BASE = {
    30: "#000000", 31: "#cd3131", 32: "#0dbc79", 33: "#e5e510",
    34: "#2472c8", 35: "#bc3fbc", 36: "#11a8cd", 37: "#e5e5e5",
    90: "#666666", 91: "#f14c4c", 92: "#23d18b", 93: "#f5f543",
    94: "#3b8eea", 95: "#d670d6", 96: "#29b8db", 97: "#ffffff",
}
DEFAULT_FG, DEFAULT_BG = "#2A251E", "#FBF8F3"

def parse_256(n: int):
    if n < 8:
        return BASE[30 + n]
    if n < 16:
        return BASE[90 + n - 8]
    n -= 16
    r, g, b = (n // 36), ((n // 6) % 6), (n % 6)
    f = lambda c: 0 if c == 0 else min(255, 55 + c * 40)
    return f"#{f(r):02x}{f(g):02x}{f(b):02x}"

def hexcolor(r: int, g: int, b: int, raw: str) -> str:
    try:
        return f"#{max(0, min(255, r)):02x}{max(0, min(255, g)):02x}{max(0, min(255, b)):02x}"
    except Exception:
        print("bad color seq:", repr(raw))
        return DEFAULT_FG

def parse_line(line: str):
    """Return list of (char, fg, bg, bold) for one capture-pane line."""
    cells = []
    fg, bg, bold = DEFAULT_FG, DEFAULT_BG, False
    i = 0
    while i < len(line):
        if line[i] == "\x1b" and i + 1 < len(line) and line[i + 1] == "[":
            m = re.match(r"\x1b\[([0-9;:]*)m", line[i:])
            if m:
                params = [p for p in re.split(r"[;:]", m.group(1)) if p != ""]
                params = [int(p) if p.isdigit() else 0 for p in params] or [0]
                j = 0
                while j < len(params):
                    p = params[j]
                    if p == 0:
                        fg, bg, bold = DEFAULT_FG, DEFAULT_BG, False
                    elif p == 1:
                        bold = True
                    elif p == 22:
                        bold = False
                    elif p == 39:
                        fg = DEFAULT_FG
                    elif p == 49:
                        bg = DEFAULT_BG
                    elif 30 <= p <= 37 or 90 <= p <= 97:
                        fg = BASE[p]
                    elif 40 <= p <= 47 or 100 <= p <= 107:
                        bg = BASE[p - 10]
                    elif p in (38, 48, 58) and j + 1 < len(params):
                        mode = params[j + 1]
                        if mode == 2 and j + 4 < len(params):
                            c = hexcolor(params[j + 2], params[j + 3], params[j + 4], m.group(0))
                            if p == 38:
                                fg = c
                            elif p == 48:
                                bg = c
                            j += 4
                        elif mode == 5 and j + 2 < len(params):
                            c = parse_256(params[j + 2])
                            if p == 38:
                                fg = c
                            elif p == 48:
                                bg = c
                            j += 2
                    j += 1
                i += m.end()
                continue
            m2 = re.match(r"\x1b\[[0-9;:]*[A-Za-z@]", line[i:])
            if m2:
                i += m2.end()
                continue
        cells.append((line[i], fg, bg, bold))
        i += 1
    return cells

# ─── PNG rendering ──────────────────────────────────────────────────────────

FONT = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 14)
CELL_W = FONT.getbbox("M")[2]
ASC, DESC = FONT.getmetrics()
CELL_H = ASC + DESC
PAD = 10

def render(cells_per_line, path):
    width = max((len(c) for c in cells_per_line), default=COLS)
    img = Image.new("RGB", (width * CELL_W + PAD * 2, len(cells_per_line) * CELL_H + PAD * 2), DEFAULT_BG)
    draw = ImageDraw.Draw(img)
    for y, cells in enumerate(cells_per_line):
        for x, (ch, fg, bg, bold) in enumerate(cells):
            px, py = PAD + x * CELL_W, PAD + y * CELL_H
            if bg != DEFAULT_BG:
                draw.rectangle([px, py, px + CELL_W - 1, py + CELL_H - 1], fill=bg)
            if ch != " ":
                draw.text((px, py), ch, font=FONT, fill=fg)
                if bold:
                    draw.text((px + 1, py), ch, font=FONT, fill=fg)
    img.save(path)
    print("wrote", path)

def capture(name):
    out = subprocess.run(
        ["tmux", "capture-pane", "-e", "-p", "-t", SESSION],
        capture_output=True, text=True,
    ).stdout
    lines = out.rstrip("\n").split("\n")
    render([parse_line(l) for l in lines], OUT / name)

# ─── Drive the app ──────────────────────────────────────────────────────────

def send(keys: str, wait: float = 0.4, enter: bool = False):
    # One quoted argument: tmux sends it literally, spaces included.
    argv = ["tmux", "send-keys", "-t", SESSION, keys]
    if enter:
        argv.append("Enter")
    subprocess.run(argv)
    time.sleep(wait)


def wait_for(substr: str, timeout: float = 8.0) -> bool:
    """Poll the pane until it shows substr (or time out)."""
    end = time.time() + timeout
    while time.time() < end:
        pane = subprocess.run(["tmux", "capture-pane", "-p", "-t", SESSION],
                              capture_output=True, text=True).stdout
        if substr in pane:
            return True
        time.sleep(0.25)
    print(f"  !! wait_for timed out: {substr!r}")
    return False


def esc_until(substr: str, tries: int = 3) -> None:
    """Send Escape (retrying) until the pane shows substr. Bare ESC can be
    eaten by kitty-mode parsing inside tmux, so verify and retry."""
    for _ in range(tries):
        send("Escape", 0.5)
        if wait_for(substr, 3.0):
            return

def boot() -> None:
    subprocess.run(["tmux", "kill-session", "-t", SESSION], capture_output=True)
    subprocess.run(["tmux", "new-session", "-d", "-s", SESSION, "-x", str(COLS), "-y", str(ROWS)])
    # the app paints empty cells with the terminal default background, so
    # give the pane the paper color to capture the light theme faithfully
    subprocess.run(["tmux", "select-pane", "-P", "bg=#FBF8F3", "-t", SESSION])
    send("cd /Users/sagar/all-configs/experimental/opentui", 0.3, enter=True)
    send("bun run src/index.tsx", 7.0, enter=True)  # wait for detection


def main():
    boot()
    capture("01-main.png")

    boot()
    send("/", 0.6)
    send("zed", 0.8)
    capture("02-search.png")

    boot()
    send("Space", 0.4)
    send("j", 0.3)
    send("Space", 0.3)
    send("j", 0.3)
    send("Space", 0.4)
    capture("03-batch-selection.png")

    boot()
    send("?", 0.8)
    wait_for("move cursor", 4.0)
    capture("04-help.png")

    boot()
    send("j", 0.4)
    send("Enter", 1.2)
    wait_for("module?", 4.0)
    capture("05-confirm-install.png")

    boot()
    send("/", 0.5)
    send("config", 0.8)
    send("Enter", 0.5)   # blur input; filter stays
    send("a", 0.5)       # select all visible (filtered) config modules
    capture("06-batch-ready.png")

    boot()
    # six fast, non-interactive config modules, selected one by one
    for term in ("aliases", "karabiner", "ghostty", "nvim", "p10k", "tmux"):
        send("/", 0.35)
        send("C-u", 0.25)     # kill line: clear stale search text
        send(term, 0.6)
        send("Enter", 0.3)    # blur input; filter stays active
        send("Space", 0.3)    # select the visible row
    wait_for("6 selected", 4.0)
    capture("06b-six-selected.png")
    send("Enter", 0.8)   # install selected batch
    send("y", 2.0)       # confirm -> run screen; catch it mid-run
    capture("07-run-mid.png")
    for _ in range(120):
        pane = subprocess.run(["tmux", "capture-pane", "-p", "-t", SESSION],
                              capture_output=True, text=True).stdout
        if "esc back" in pane:  # idle footer: run finished
            break
        time.sleep(0.5)
    capture("08-run-done.png")

    send("q", 0.5)  # exit the run screen? no-op; kill below
    subprocess.run(["tmux", "kill-session", "-t", SESSION], capture_output=True)


if __name__ == "__main__":
    main()
