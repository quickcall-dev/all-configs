"""Entry point for all-configs.

The interactive TUI is the OpenTUI rewrite in ``cli/``; the
original Textual TUI is archived under ``archive/textual-tui/``. This module
locates Bun and hands off to the TypeScript app so both
``python3 -m allconfigs`` and ``./install.sh`` keep working.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path


def main() -> int:
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("all-configs TUI needs an interactive terminal; use ./install.sh <module>", file=sys.stderr)
        return 1

    root = Path(__file__).resolve().parents[1]
    bun = shutil.which("bun")
    if not bun:
        # Bun is often installed to ~/.bun/bin by the official script while
        # the invoking shell (install chains, tmux, sudo) never sources the
        # rc files that add it to PATH.
        for candidate in (
            Path.home() / ".bun" / "bin" / "bun",
            Path.home() / ".local" / "share" / "bun" / "bun",
        ):
            if candidate.is_file() and os.access(candidate, os.X_OK):
                bun = str(candidate)
                break
    if bun:
        os.chdir(root)
        os.execvp(bun, [bun, "run", "cli/src/index.tsx"])

    # No Bun: fall back to guidance; the platform check needs 3.11+ (tomllib).
    from allconfigs.modules import PLATFORM

    if PLATFORM == "unsupported":
        print(f"all-configs supports macOS and Linux only (got {sys.platform})", file=sys.stderr)
    print(
        "The all-configs TUI needs Bun: https://bun.sh\n"
        "Or run a module directly: ./install.sh <module>",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
