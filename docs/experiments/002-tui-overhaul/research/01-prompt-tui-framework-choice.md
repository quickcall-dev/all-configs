---
topic: "tui-framework-choice"
experiment: 002-tui-overhaul
created: "2026-11-10 13:56 UTC"
---


## Question

The all-configs installer TUI (`tui/`, Textual, launched by `install.sh` via `uv run --with textual`) has real bugs: no TTY for sudo, a fake splash, wrong installed-state detection, and an unsafe uninstall. Questions:

1. Is Textual good enough for a production-grade installer TUI, or should it move to Rich, gum, Bubble Tea, or something else?
2. How should the TUI run installers so that sudo, brew prompts and colour output work?
3. How should it be tested without touching the host machine (Docker or something else)?

Constraints: macOS and Linux only. Bootstrap must work on a fresh machine, where today only bash and curl exist and uv is fetched on demand.
