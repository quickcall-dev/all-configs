#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -t, --token <token>  Hugging Face access token (optional)
  -h, --help           Show this help

Environment variables:
  HF_TOKEN             Hugging Face access token

Examples:
  ${0##*/}
  ${0##*/} -t hf_...
  HF_TOKEN=hf_... ${0##*/}
USAGE
  exit 0
}

TOKEN="${HF_TOKEN:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--token) TOKEN="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

step "Installing Hugging Face CLI"

if command -v hf &> /dev/null; then
  ok "hf ${D}$(hf --version)${R}"
else
  warn "hf not found - installing via hf.co/install.sh"
  curl -LsSf https://hf.co/cli/install.sh | bash

  # Add to PATH if installed in a user-local directory
  if [[ -d "$HOME/.local/bin" ]] && [[ -f "$HOME/.local/bin/hf" ]]; then
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
      [[ -f "$rc" ]] || continue
      if ! grep -q "\.local/bin" "$rc" 2>/dev/null; then
        printf '\n# hf cli\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
        ok "added ~/.local/bin to PATH in $(basename "$rc")"
      else
        ok "~/.local/bin already in PATH in $(basename "$rc")"
      fi
    done
  fi
fi

# Ensure hf is on PATH for the rest of this script
export PATH="$HOME/.local/bin:$PATH"
ok "hf ${D}$(hf --version)${R}"

step "Configuring git credential helper"
if [[ "$(git config --global credential.helper)" != "store" ]]; then
  git config --global credential.helper store
  ok "git credential.helper set to store"
else
  ok "git credential.helper already set to store"
fi

if [[ -n "$TOKEN" ]]; then
  step "Authenticating with Hugging Face"
  hf auth login --token "$TOKEN" --add-to-git-credential
  ok "HF authentication saved"
else
  warn "No HF_TOKEN provided - run hf auth login manually"
fi

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}hf whoami${R} to verify"
echo ""
