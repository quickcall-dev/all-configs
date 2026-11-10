from __future__ import annotations

import sys

from tui.modules import PLATFORM


def main() -> int:
    if PLATFORM == "unsupported":
        print(f"all-configs supports macOS and Linux only (got {sys.platform})", file=sys.stderr)
        return 1
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("all-configs TUI needs an interactive terminal; use ./install.sh <module>", file=sys.stderr)
        return 1

    from tui.app import AllConfigsApp

    return AllConfigsApp().run() or 0


if __name__ == "__main__":
    sys.exit(main())
