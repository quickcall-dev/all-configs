#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -n, --name <name>      Git user.name
  -e, --email <email>    Git user.email
  -E, --editor <editor>  Git core.editor (optional)
  -h, --help             Show this help

Environment variables:
  GIT_NAME, GIT_EMAIL, GIT_EDITOR

Examples:
  ${0##*/} -n "Sagar Sarkale" -e sagar@example.com
  GIT_NAME="Sagar" GIT_EMAIL="sagar@example.com" ${0##*/}
USAGE
  exit 0
}

GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
GIT_EDITOR="${GIT_EDITOR:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name) GIT_NAME="$2"; shift 2 ;;
    -e|--email) GIT_EMAIL="$2"; shift 2 ;;
    -E|--editor) GIT_EDITOR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

step "Installing GitHub CLI"

if ! command -v gh &>/dev/null; then
  warn "gh not found — installing"
  if [[ "$PLATFORM" == "mac" ]]; then
    ensure_cmd brew brew
    brew install gh
  else
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq curl gnupg
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq gh
    elif command -v dnf &>/dev/null; then
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
      sudo dnf install -y gh
    else
      fail "No supported package manager for gh"
      exit 1
    fi
  fi
  ok "gh installed"
else
  ok "gh ${D}$(gh --version 2>/dev/null | head -1)${R}"
fi

step "Configuring git"

backup_file "$HOME/.gitconfig"

if [[ -n "$GIT_NAME" ]]; then
  git config --global user.name "$GIT_NAME"
  ok "git user.name ${D}→ $GIT_NAME${R}"
else
  warn "git user.name unchanged (pass -n or set GIT_NAME)"
fi

if [[ -n "$GIT_EMAIL" ]]; then
  git config --global user.email "$GIT_EMAIL"
  ok "git user.email ${D}→ $GIT_EMAIL${R}"
else
  warn "git user.email unchanged (pass -e or set GIT_EMAIL)"
fi

git config --global init.defaultBranch main
git config --global push.default simple
ok "git init.defaultBranch = main, push.default = simple"

if [[ -n "$GIT_EDITOR" ]]; then
  git config --global core.editor "$GIT_EDITOR"
  ok "git core.editor ${D}→ $GIT_EDITOR${R}"
fi

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}gh auth login${R} to authenticate"
echo -e "  ${D}Git config: ~/.gitconfig${R}"
echo ""
