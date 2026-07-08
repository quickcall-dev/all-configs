#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -h, --help  Show this help

Examples:
  ${0##*/}
USAGE
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

step "Installing Hugging Face CLI"

if command -v hf &> /dev/null; then
  ok "hf ${D}$(hf --version)${R}"
  exit 0
fi

warn "hf not found — installing via hf.co/install.sh"

curl -LsSf https://hf.co/cli/install.sh | bash

# Add to PATH if installed in a user-local directory
if [[ -d "$HOME/.local/bin" ]] && [[ -f "$HOME/.local/bin/hf" ]]; then
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$rc" 2>/dev/null; then
      printf n# hf clinexport PATH=/Users/sagar/.local/bin:/Users/sagar/.pi/agent/bin:/Users/sagar/.bun/bin:/Users/sagar/.railway/bin:/Users/sagar/.local/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/pkg/env/global/bin:/opt/homebrew/bin:/Applications/Ghostty.app/Contents/MacOSn >> "$rc"
      ok "added ~/.local/bin to PATH in $(basename "$rc")"
    else
      ok "~/.local/bin already in PATH in $(basename "$rc")"
    fi
  done
fi

ok "hf installed ${D}$(hf --version)${R}"

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}hf --help${R} to start"
echo -e "  ${D}Log in with: hf auth login${R}"
echo ""
