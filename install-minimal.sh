#!/usr/bin/env bash
# Bare-minimum headless install for a fresh Linux/GPU container.
# Run: ./install-minimal.sh -n "Your Name" -e you@example.com
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -n, --name <name>    Git user.name
  -e, --email <email>  Git user.email
  -h, --help           Show this help

Environment variables:
  GIT_NAME, GIT_EMAIL

Examples:
  ${0##*/} -n "Sagar Sarkale" -e sagar@example.com
  GIT_NAME="Sagar" GIT_EMAIL="sagar@example.com" ${0##*/}
USAGE
  exit 0
}

GIT_NAME="${GIT_NAME:-$(git config --global user.name 2>/dev/null || true)}"
GIT_EMAIL="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)  GIT_NAME="$2"; shift 2 ;;
    -e|--email) GIT_EMAIL="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
  fail "GIT_NAME and GIT_EMAIL are required (use -n/-e or env vars)"
  usage
fi

export GIT_NAME GIT_EMAIL
export EMAIL="$GIT_EMAIL"

# Ensure nvm Node 24 is preferred on Vast.ai / nvm-managed images.
if [[ -s "/opt/nvm/nvm.sh" ]]; then
  export NVM_DIR="/opt/nvm"
  # shellcheck source=/dev/null
  source "$NVM_DIR/nvm.sh"
  nvm use v24 &>/dev/null || nvm alias default v24 &>/dev/null || true
  export PATH="$NVM_DIR/versions/node/v24.19.0/bin:$HOME/.local/bin:$PATH"
else
  export PATH="$HOME/.local/bin:$PATH"
fi

# Persist ~/.local/bin for future login shells. ~/.bashrc may return early on
# non-interactive shells, so keep PATH bootstrap in profile-level files too.
for rc in "$HOME/.profile" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] || touch "$rc"
  python3 - "$rc" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
text = text.replace('\n# local user bin\nexport PATH="$HOME/.local/bin:$PATH"\n', '\n')
if '# local user bin' not in text:
    text += '\n# local user bin\ncase ":$PATH:" in\n  *":$HOME/.local/bin:"*) ;;\n  *) export PATH="$HOME/.local/bin:$PATH" ;;\nesac\n'
path.write_text(text)
PY
done

step "Bare-minimum install: $GIT_NAME <$GIT_EMAIL>"

# Core tools and utilities first.
for mod in uv node bun zoxide ffmpeg ncdu yt-dlp tmux tailscale; do
  step "Installing $mod"
  bash "$ROOT_DIR/$mod/install.sh"
done

# Git, GitHub CLI, and SSH key for GitHub.
step "Installing github"
bash "$ROOT_DIR/github/install.sh"

step "Generating SSH key for GitHub"
# Use explicit args so the container's HOSTNAME env var doesn't override the default.
bash "$ROOT_DIR/ssh-keygen/install.sh" -H github.com -u git -e "$GIT_EMAIL" -k id_ed25519_github

# Debian/Ubuntu package binaries often have different names than the rest of the
# dotfiles expect. Install them early and symlink the expected names.
step "Ensuring Debian binary aliases (fd, bat)"
mkdir -p "$HOME/.local/bin"
if ! command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq fd-find
fi
if ! command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq bat
fi
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    ok "fd → fdfind"
fi
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    ok "bat → batcat"
fi
if command -v bat &>/dev/null; then ok "bat present"; fi
if command -v fd &>/dev/null; then ok "fd present"; fi

# File managers / editors.
for mod in superfile nvim; do
  step "Installing $mod"
  bash "$ROOT_DIR/$mod/install.sh"
done

# AI agent stack.
for mod in claude pi caveman hf statusline; do
  step "Installing $mod"
  if [[ "$mod" == "statusline" ]]; then
    ensure_cmd jq jq
  fi
  bash "$ROOT_DIR/$mod/install.sh"
done

# Terminal cosmetics / fonts.
for mod in fonts ghostty; do
  step "Installing $mod"
  bash "$ROOT_DIR/$mod/install.sh"
done

echo ""
echo -e "  ${GRN}Done!${R} Minimal install complete."
echo -e "  ${D}Add this GitHub public key:${R}"
echo ""
cat "$HOME/.ssh/id_ed25519_github.pub" 2>/dev/null || warn "GitHub public key not found"
echo ""
