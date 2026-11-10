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
| `/` | search (name, description, kind, or status); `Enter` or `↓` back to the list, filter kept |
| `Esc` | step back one layer: clear the search, then clear the selection; on the run screen, abort (asks first) or go back when finished. The footer shows what it will do. |
| `Space` | toggle module under cursor |
| `a` / `n` / `i` | select all visible / none / invert |
| `Enter` | install selected (or the module under the cursor); installed modules are re-applied |
| `u` | uninstall selected — app/cli modules only, config modules are never uninstalled |
| `r` | re-detect install status |
| `?` | help |
| `q` / `Ctrl+C` | quit |

Installers run in a pseudo-terminal. When one asks for input (`sudo` password,
`read -p` prompt), a reply box appears; passwords go straight to the installer
and are never logged. Every run writes
a log to `~/.local/state/all-configs/logs/`.

TUI tests use fake modules and a temporary `$HOME`, so they never touch the system:

```bash
./tests/run-tui-tests.sh
```

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
| **moshi** | Moshi remote-login hook + mosh transport via Homebrew |
| **tailscale** | Tailscale mesh VPN via Homebrew |
| **karabiner** | Karabiner-Elements key remaps |
| **node** | Node.js, npm, npx via system package manager |
| **nvim** | Neovim config with LazyVim, treesitter, fzf |
| **pi** | Pi coding agent CLI, settings, and package extensions |
| **skills** | QuickCall skills + Pi system skills |
| **multi-github** | Two GitHub accounts on one machine — per-account SSH aliases, directory-scoped git identity, URL rewriting so pushes never use the wrong account |
| **ssh-keygen** | Generate SSH keys, update `~/.ssh/config`, test GitHub auth |
| **aqua-voice** | Installs Aqua Voice via Homebrew |
| **keycastr**   | Installs KeyCastr via Homebrew |
| **presentify** | Installs Presentify from the Mac App Store |
| **statusline** | Status bar + turn counter for Claude Code |
| **superfile** | superfile (spf) TUI file manager + vim-style config, zoxide jump, cheat sheet |
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

### multi-github

Run two (or more) GitHub accounts on one machine without ever pushing or
committing as the wrong one. Sets up per-account SSH host aliases, a
directory-scoped git identity, and URL rewriting so every GitHub remote inside
your work directory authenticates as the work account — even `https://` URLs:

```bash
./multi-github/install.sh -p <personal-login> -w <work-login> -d "$HOME/work" \
  -W "<id>+<work-login>@users.noreply.github.com"
```

No account names or emails are stored in the script — all four options are
required. It generates `~/.ssh/id_ed25519_<login>` per account, adds
`github.com` (personal) and `github-<work-login>` (work) host aliases to
`~/.ssh/config`, and registers a `gitdir` include in `~/.gitconfig` so repos
under the work dir commit as the work identity. After running, add each
printed public key to its account at `https://github.com/settings/ssh/new`,
then verify with `ssh -T git@github.com` and
`ssh -T git@github-<work-login>`.

Note: `gh` CLI commands still use the gh-active account (`gh auth status`) —
this module fixes git pushes/authorship, not gh API calls.

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
name = "my-module"                       # must match the directory name
description = "Short one-line description"
platforms = ["mac", "linux"]
kind = "cli"                             # app | cli | config

[detect]                                 # all keys optional
commands = ["my-tool"]                   # tool present if any is on PATH
brew = ["my-tool"]                       # ...or any brew formula/cask (macOS)
apps = ["My Tool"]                       # ...or /Applications/My Tool.app (macOS)
paths = ["~/.config/my-tool/config"]     # config applied if all exist
paths_mac = []                           # extra paths per platform
paths_linux = []

[uninstall]                              # omit to disable uninstall
brew = ["my-tool"]                       # macOS package names
packages = ["my-tool"]                   # Linux (apt/dnf/pacman) package names
```

Status shows `installed` when the tool is present and the config applied,
`partial` when only one is true, and `?` when there is nothing to detect.
`install.sh` must be idempotent: the TUI re-runs it to re-apply config.
If it needs input, prompt only when stdin is a terminal (`[[ -t 0 ]]`) so
`./install.sh <module>` in scripts still fails fast instead of hanging.

The root `install.sh` auto-discovers it; `./install.sh --list` shows what it found.
