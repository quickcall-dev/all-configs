# all-configs

Modular dotfiles and developer environment suite for macOS and Linux — editors, terminals, AI tools, and productivity apps.

## Quick start

```bash
git clone https://github.com/quickcall-dev/all-configs.git
cd all-configs

# Interactive Textual TUI — search, select, install
./install.sh

# Or install specific modules directly
./install.sh nvim tmux zoxide github ssh-keygen
```

The TUI is built with [Textual](https://textual.textualize.io/). It uses [uv](https://docs.astral.sh/uv/) to provision its Python environment.

Keys inside the TUI:

| Key | Action |
|-----|--------|
| `Tab` | move focus between search and module list |
| `/` or just type | search modules |
| `Space` | toggle selected module |
| `a` | select all visible |
| `n` | select none |
| `i` | invert selection |
| `Enter` | install selected (skips already-installed) |
| `u` | uninstall selected modules |
| `?` | show keybindings |
| `q` / `Ctrl+Q` / `Ctrl+C` | quit |

## Modules

| Module | What it does |
|--------|-------------|
| **browsers** | Brave and Google Chrome via Homebrew |
| **caveman** | caveman Claude Code plugin — terse output mode |
| **claude** | Claude Code CLI via claude.ai/install.sh |
| **fonts** | Meslo Nerd Font for terminal/editor icons |
| **ghostty** | Ghostty terminal config + themes |
| **github** | GitHub CLI (`gh`) and global git config without credentials |
| **docker** | Installs Docker Desktop via Homebrew |
| **karabiner** | Karabiner-Elements key remaps |
| **node** | Node.js, npm, npx via system package manager |
| **nvim** | Neovim config with LazyVim, treesitter, fzf |
| **pi** | Pi coding agent CLI, settings, and package extensions |
| **skills** | QuickCall skills + Pi system skills |
| **ssh-keygen** | Generate SSH keys, update `~/.ssh/config`, test GitHub auth |
| **aqua-voice** | Installs Aqua Voice via Homebrew |
| **keycastr**   | Installs KeyCastr via Homebrew |
| **presentify** | Installs Presentify from the Mac App Store |
| **statusline** | Status bar + turn counter for Claude Code |
| **tmux** | tmux config, TPM, vim nav, clipboard |
| **uv** | Astral uv — fast Python package and project manager |
| **vscode** | VS Code user settings, keybindings, and tasks |
| **zed** | Zed editor settings with Nerd Font terminal icons |
| **zoxide** | Smarter `cd` command with learning and fzf integration |
| **p10k** | Powerlevel10k prompt config and theme |
| **raycast** | Installs Raycast via Homebrew |
| **bitwarden** | Installs Bitwarden via Homebrew |
| **rectangle** | Installs Rectangle via Homebrew |
| **ffmpeg** | Cross-platform audio/video conversion and streaming toolkit |
| **ncdu** | Interactive disk usage analyzer |
| **yt-dlp** | YouTube/video downloader and extractor |

## Standalone usage

Each module can be installed directly:

```bash
./nvim/install.sh
./tmux/install.sh
./zoxide/install.sh
./fonts/install.sh
```

### pi

Install the Pi coding agent, copy settings, and install package extensions:

```bash
./pi/install.sh
```

Configured packages (in `pi/settings.json`):
- `npm:@tintinweb/pi-subagents`
- `npm:pi-web-access`
- `npm:pi-caveman`
- `https://github.com/obra/superpowers`

### skills

Install QuickCall skills and Pi system skills (everything under `skills/`):

```bash
./skills/install.sh
```

To add a Pi system skill, drop it into the `skills/` folder and re-run the installer.

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
- `uv` for the interactive TUI (installed automatically if missing)

If you cannot use passwordless sudo, run the relevant module as root or install the system dependencies manually first.

## Adding a new module

Create a directory with an `install.sh` and a `module.toml`:

```toml
name = "my-module"
description = "Short one-line description"
platforms = ["mac", "linux"]
```

The root `install.sh` auto-discovers it.
