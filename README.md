# all-configs

Modular dotfiles and environment setup for Claude Code, terminal tools, editors, and developer tooling.

## Quick start

```bash
git clone https://github.com/quickcall-dev/all-configs.git
cd all-configs

# Interactive TUI — pick what you want
./install.sh

# Or install specific modules directly
./install.sh nvim tmux zoxide github ssh-keygen
```

## Modules

| Module | What it does |
|--------|-------------|
| **caveman** | caveman Claude Code plugin — terse output mode |
| **claude** | Claude Code CLI via claude.ai/install.sh |
| **fonts** | Meslo Nerd Font for terminal/editor icons |
| **ghostty** | Ghostty terminal config + themes |
| **github** | GitHub CLI (`gh`) and global git config without credentials |
| **karabiner** | Karabiner-Elements key remaps |
| **node** | Node.js, npm, npx via system package manager |
| **nvim** | Neovim config with LazyVim, treesitter, fzf |
| **skills** | QuickCall Claude Code skills |
| **ssh-keygen** | Generate SSH keys, update `~/.ssh/config`, test GitHub auth |
| **statusline** | Status bar + turn counter for Claude Code |
| **tmux** | tmux config, TPM, vim nav, clipboard |
| **uv** | Astral uv — fast Python package and project manager |
| **hf** | Hugging Face CLI (hf) via hf.co/install.sh |
| **zoxide** | Smarter `cd` command with learning and fzf integration |

## Standalone usage

Each module can be installed directly:

```bash
./nvim/install.sh
./tmux/install.sh
./zoxide/install.sh
./fonts/install.sh
```

### github

Install `gh` and configure git without storing credentials:

```bash
./github/install.sh -n "Sagar Sarkale" -e sagar@example.com

# or with env vars
GIT_NAME="Sagar Sarkale" GIT_EMAIL="sagar@example.com" ./github/install.sh
```

Then run `gh auth login` to authenticate.

### ssh-keygen

Generate an SSH key, add it to `~/.ssh/config`, and test GitHub authentication:

```bash
./ssh-keygen/install.sh -e sagar@example.com -u sagar -H github.com

# For a different server
./ssh-keygen/install.sh -e sagar@example.com -u sagar -H contabo.example.com -k id_ed25519_contabo
```

Copy the printed public key and add it to the target host.

## Requirements

- macOS or Linux
- `bash` 4+
- `git`, `curl`
- `sudo` access (modules install system packages like `build-essential`, `fontconfig`, `gh`, `nodejs`, `nvim`, `uv`)
- On headless/VM setups: **passwordless sudo** is recommended so modules can install packages without prompts
- Optional: `jq` for statusline, `python3.11+` or `uv` for the TUI installer

If you cannot use passwordless sudo, run the relevant module as root or install the system dependencies manually first.

## Adding a new module

Create a directory with an `install.sh` and a `module.toml`:

```toml
name = "my-module"
description = "Short one-line description"
platforms = ["mac", "linux"]
```

The root `install.sh` auto-discovers it.
