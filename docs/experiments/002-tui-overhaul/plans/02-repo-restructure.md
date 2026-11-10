---
title: "repo-restructure"
experiment: 002-tui-overhaul
created: "2026-11-10 15:06 UTC"
---


## Problem

- **No separation between the system and its content.** 44 module dirs sit at the repo root next to `lib/`, `tui/`, `hooks/`, `docs/`, `tests/` and loose files (`skills-lock.json`, `demo.gif`, `install-minimal.sh`).
- **Copy-paste instead of shared building blocks.** 14 modules are about 17 lines of boilerplate around one `brew_install_cask` call. Seven scripts each hand-roll the same "append to `.zshrc`/`.bashrc`" loop. Eleven do backup-then-copy and four do symlinks, each in their own way.
- **Hidden dependencies.** caveman needs claude, skills needs npx, statusline needs jq plus `hooks/turn-counter.sh` from outside its dir, superfile needs zoxide. Nothing declares this, so install order is luck.
- **Two sources of truth.** `install.sh` (bash) and the TUI (Python) each discover and run modules separately. `install-minimal.sh` is a third hand-written list.
- **Config modules can't be undone.** Nothing records what was linked or copied, so uninstall has to be disabled.

## Proposed layout

```
all-configs/
├── install.sh                 # entry: TUI, or `./install.sh tmux nvim`, or `--profile gpu-box`
├── modules/
│   ├── tmux/
│   │   ├── module.toml        # what it is + declarative steps
│   │   ├── install.sh         # OPTIONAL: only for logic toml can't express
│   │   └── files/             # config files this module links/copies
│   │       └── .tmux.conf.local
│   ├── slack/
│   │   └── module.toml        # no install.sh at all
│   └── statusline/
│       ├── module.toml
│       └── files/ (statusline.sh, turn-counter.sh)   # hooks/ folded in
├── profiles/
│   ├── mac-workstation.toml   # named module sets
│   └── gpu-box.toml           # replaces install-minimal.sh
├── allconfigs/                # one Python package = one engine
│   ├── manifest.py            # parse + validate module.toml, dependency graph
│   ├── detect.py              # status (current tui/modules.py)
│   ├── steps.py               # brew/apt, link, copy, rc-line, run-script
│   ├── state.py               # ~/.local/state/all-configs/state.json (what we did)
│   ├── runner.py              # pty runner (current tui/runner.py)
│   ├── cli.py                 # non-interactive frontend: install/uninstall/list/status
│   └── tui/                   # Textual frontend (current tui/)
├── lib/
│   └── common.sh              # helpers still sourced by the remaining install.sh scripts
├── tests/
│   ├── unit/                  # engine: manifest, deps, steps against temp HOME
│   ├── tui/                   # Pilot tests (current tests/tui_tests)
│   └── docker/                # later: Linux matrix
└── docs/
```

Folders stay **flat** under `modules/`. Grouping comes from `kind` plus tags in the toml, and the TUI shows the groups. Category folders (`apps/`, `cli/`) would mean moving files every time a module changes kind.

## Declarative module.toml (superset of today's)

```toml
name = "tmux"
description = "tmux config, oh-my-tmux, vim nav, clipboard"
platforms = ["mac", "linux"]
kind = "config"
tags = ["terminal"]
requires = []                         # module names; engine orders + offers to add them

[packages]                            # installed via brew / apt / dnf / pacman
brew = ["tmux"]
apt = ["tmux"]
dnf = ["tmux"]

[[git]]                               # clone/update
repo = "https://github.com/gpakosz/.tmux.git"
dest = "~/.oh-my-tmux"

[[link]]                              # symlink with automatic backup of what was there
src = "~/.oh-my-tmux/.tmux.conf"      # absolute or ~ = external; else relative to files/
dest = "~/.tmux.conf"
[[link]]
src = ".tmux.conf.local"
dest = "~/.tmux.conf.local"

[[rc]]                                # idempotent marked block in ~/.zshrc / ~/.bashrc
shells = ["zsh", "bash"]
text = 'source "$HOME/.config/all-configs/tmux-helpers.sh"'

[script]                              # optional, runs after declarative steps
install = "install.sh"

[detect]                              # mostly auto-derived now (packages + link dests)
commands = ["tmux"]
```

A cask-only app becomes 6 lines:

```toml
name = "slack"
description = "Slack"
platforms = ["mac"]
kind = "app"
[packages]
brew_cask = ["slack"]
```

## Why this is better

| Today | After |
|---|---|
| 44 install.sh, ~2,200 lines, mostly boilerplate | ~15 scripts left, only for real logic (nvim build deps, multi-github, ssh-keygen, bun rc cleanup…) |
| Detection hand-written per module | Derived from `packages` + `link` dests, plus state.json |
| Uninstall disabled for config | Engine reverses what state.json says it did: unlink, restore backup, remove rc block. Config uninstall becomes safe *and* exact |
| Hidden deps | `requires` gives topological order. The TUI says "caveman needs claude, add it?" |
| bash and Python discover modules separately | One engine. `./install.sh tmux` → `allconfigs.cli install tmux`. The TUI uses the same code |
| `install-minimal.sh` hand-coded | `profiles/gpu-box.toml` plus `./install.sh --profile gpu-box` |

Cost: direct mode (`./install.sh tmux`) needs uv/Python too. `install.sh` already bootstraps uv in one curl, so this only adds a few seconds on a fresh machine.

## Migration (each phase leaves the repo working)

1. **Move** (mechanical): `git mv <mod> modules/<mod>`. Fix `ROOT_DIR` in each script: `common.sh` exports `ROOT_DIR`, and scripts use `$(cd "$SCRIPT_DIR/../.." …)`. Rename `tui/` to `allconfigs/tui/`. Move `hooks/turn-counter.sh` to `modules/statusline/files/`. Move `skills-lock.json` to `modules/skills/`. Everything else unchanged. Tests green.
2. **Engine + packages**: add `manifest/steps/state/cli`, plus `[packages]` support. Convert the 14 cask-only modules and the plain CLI ones (ffmpeg, ncdu, yt-dlp, zoxide) and delete their install.sh.
3. **Links / rc / git**: convert the config modules (aliases, tmux, ghostty, p10k, zed, vscode, tinycast, karabiner, statusline, pi). state.json enables config uninstall, then remove the "disabled for config" rule.
4. **Deps + profiles**: `requires`, a dependency prompt in the TUI, and `profiles/`. Delete `install-minimal.sh` and the legacy `tmux/uninstall.sh`.
5. **Docker matrix** (Ubuntu/Debian/Fedora) running `./install.sh --profile gpu-box` and per-module installs.

## Open decisions

1. **Engine in Python (recommended)**, or keep direct mode pure bash (the toml then has to stay bash-parseable, which limits how declarative it can be)?
2. **Do all phases**, or stop after phase 1 (move only) or phase 2?
3. **Profiles**: which sets do you want? Suggested: `mac-workstation`, `gpu-box` (= install-minimal), `linux-dev`.

Note: phase 1 moves `tui/`. Wait for the running aesthetics agent to finish before starting.

## Decisions (2026-11-10, user)

- **Both bash and Python.** Interpretation: **bash is the executor, Python is the frontend.**
  - `lib/engine.sh` parses module.toml and runs every step (packages, git, link, rc, script, state). `./install.sh tmux` and `./install.sh --profile gpu-box` need only bash, curl and git, which suits throwaway boxes.
  - Python (`allconfigs/`) handles the TUI, detection display, dependency planning and prompts. It runs the *same* `lib/engine.sh` in the pty, so there is no second implementation of steps.
  - Consequence: module.toml is restricted to a **bash-parseable TOML subset**: `key = "str"`, `key = ["a", "b"]`, `key = true`, `[table]`, `[[array-of-tables]]`, one value per line, no inline tables or multi-line strings. A test parses every module.toml with both `tomllib` and `lib/toml.sh` and asserts identical results, so the subset can't drift.
  - State file `~/.local/state/all-configs/state.tsv` (line-based, written by bash, read by both): `module<TAB>action<TAB>target<TAB>backup`.
- **Scope:** all 5 phases.
- **Profiles:** `mac-workstation`, `linux-dev`, `gpu-box`. The common case is a throwaway Linux/Mac instance that needs all or part of a profile fast. Add `bootstrap.sh` for a fresh box: `curl -fsSL <raw>/bootstrap.sh | bash -s -- --profile gpu-box` clones the repo to `~/all-configs` (or updates it) and runs the profile. Profiles may include or exclude modules and extend other profiles.
