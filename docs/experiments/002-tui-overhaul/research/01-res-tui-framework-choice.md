---
topic: "tui-framework-choice"
experiment: 002-tui-overhaul
created: "2026-11-10 13:56 UTC"
---


## TL;DR

Keep **Textual**. The bugs come from the execution model and the module metadata, not from the framework. Rich is a rendering library, not an interactive TUI framework: Textual is built on Rich. Moving to Rich would mean hand-building input handling and losing features. Bubble Tea is the only option with clearly better polish, and it costs a full rewrite plus a Go build and distribution pipeline.

## Options compared

| Option | What it is | Pros | Cons | Fit |
|---|---|---|---|---|
| **Textual** (Python, current) | Full TUI framework: widgets, CSS, async, Pilot test harness, snapshot tests | Already written. Actively maintained (v8.2.x, packaged in Debian testing Sep 2026). `App.suspend()` hands the real TTY to a child process. Headless `run_test()` + `pytest-textual-snapshot` for CI | Needs Python, solved by uv. About 1s cold start. Theme API changed across majors, so pin the version | **Recommended** |
| Rich only | Rendering: tables, progress bars, live displays | Simple. Great for *non-interactive* progress output | No focus, keybindings, modal screens or search. You end up reimplementing a TUI | Use *inside* Textual's run phase, not instead of it |
| gum (Charm, shell) | CLI prompts: choose, filter, confirm, spin | Pure bash, which matches the repo. Used by Omakub-style installers. Zero Python | One prompt at a time: no live status table, no in-place search plus multi-select plus status columns. Extra binary to bootstrap | Good for `install-minimal.sh`, too limited for the main TUI |
| Bubble Tea + Bubbles + Lip Gloss (Go) | Elm-style TUI framework | Best-looking TUIs today. Single static binary, instant start. `tea.ExecProcess` suspends for child processes | Full rewrite. Must build and ship darwin/linux × arm64/amd64 binaries or require Go. Separate language from the bash modules | Only worth it if the installer becomes a product |
| Ratatui (Rust) | Immediate-mode TUI | Fast, robust | Same distribution cost as Go, more code for forms | Overkill |
| whiptail/dialog | Classic curses dialogs | Preinstalled on many Linux distros | Dated UX, not on macOS by default | No |

## How good installers handle running steps

The pattern seen in Bubble Tea's `ExecProcess`, tview's `app.Suspend`, Textual's `App.suspend()` and Omakub:

1. **Pick** in a rich UI: search, multi-select, status.
2. **Authenticate once** up front: `sudo -v`, plus a keep-alive loop for the run.
3. **Run** each step in a **pseudo-terminal (PTY)**, not a pipe. A PTY keeps colours and spinners working and makes `isatty()` true, which brew and apt expect. Output streams into a log pane, with a per-module status (pending / running / ok / failed / skipped) and elapsed time.
4. If a step *needs* interactive input (for example `gh auth login`), **suspend** the UI, run it on the real terminal, then resume.
5. **Summarize** at the end: per-module result, path to the full log file, and a re-run-failed action.

## Testing

- **Docker** isolates the system fully, but **only for Linux**: no macOS containers exist. Use it for an Ubuntu/Debian/Fedora/Arch matrix of `./install.sh <mod>`. Add a non-root user with passwordless sudo to mirror a real machine.
- **macOS isolation**: Tart (Cirrus Labs) runs macOS VMs on Apple Silicon with snapshot and reset. GitHub Actions `macos-14`/`macos-15` runners are throwaway Macs in CI.
- **TUI logic needs no real installs**: point `AllConfigsApp(root=fixture_dir)` at fake modules whose `install.sh` just echo, sleep or exit 1. Drive it with Pilot (`app.run_test()`) and lock down layout with `pytest-textual-snapshot`. This runs anywhere in milliseconds and never touches the system.
- **Config-only modules** (dotfiles, symlinks) can be tested on the host with `HOME=$(mktemp -d)`, but Docker is simpler and safer.

## Sources

- Textual roadmap: https://textual.textualize.io/roadmap
- Debian textual 8.2.8 tracker: https://tracker.debian.org/pkg/textual
- Textual suspend example: https://sources.debian.org/src/textual/2.1.2-1.1/docs/examples/app/suspend_process.py
- Textual suspend tests (headless raises): https://sources.debian.org/src/textual/2.1.2-2/tests/test_suspend.py
- gum: https://beta.pkg.go.dev/github.com/charmbracelet/gum
- Omakub (gum-based menus): https://docsearch.algolia.com/mcp/docs/repo/basecamp/omakub
- gum dotfiles bootstrap example: https://dev.to/mikula/automated-macos-setup-with-dotfiles-4221
- sudo piped-stdout issue: https://lists.snapcraft.io/archives/foundations-bugs/2026-March/547165.html
