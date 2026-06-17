# all-configs

Modular configs for Claude Code, tmux, neovim, ghostty, karabiner, and more.

<img src="demo.gif" width="600" />

## Install

```bash
git clone https://github.com/quickcall-dev/all-configs.git
cd all-configs

# Interactive TUI — pick what you want
./install.sh

# Or install specific modules directly
./install.sh statusline tmux nvim
```

Each module can also be installed standalone:

```bash
./statusline/install.sh
./tmux/install.sh
./nvim/install.sh
```

## Modules

| Module | What it does |
|--------|-------------|
| **caveman** | caveman Claude Code plugin — ~75% fewer output tokens |
| **claude** | Claude Code CLI via claude.ai/install.sh |
| **ghostty** | Ghostty terminal config + themes |
| **karabiner** | Karabiner-Elements key remaps |
| **node** | Node.js, npm, npx via system package manager |
| **nvim** | Neovim config with Lazy, treesitter, fzf |
| **skills** | QuickCall Claude Code skills |
| **statusline** | Status bar + turn counter for Claude Code |
| **tmux** | tmux config, TPM, vim nav, clipboard |

## Requirements

macOS or Linux, [jq](https://jqlang.github.io/jq/) (for statusline), [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

The interactive installer bootstraps its own Textual TUI in a temporary venv (uses `uvx` if available).

## Adding a new module

Create a directory with an `install.sh` and a `module.toml` inside it. The root installer auto-discovers it.

```toml
name = "my-module"
description = "Short one-line description"
platforms = ["mac", "linux"]
```
