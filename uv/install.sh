#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -d, --dir <dir>  Installation directory (default: /usr/local/bin)
  -h, --help       Show this help

Examples:
  ${0##*/}
  ${0##*/} -d ~/.local/bin
USAGE
  exit 0
}

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

step "Installing uv"

if command -v uv &> /dev/null; then
  ok "uv ${D}$(uv --version)${R}"
  exit 0
fi

warn "uv not found — installing via official installer"

mkdir -p "$INSTALL_DIR"

if [[ "$INSTALL_DIR" == /usr/local/bin || "$INSTALL_DIR" == /usr/bin ]]; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$INSTALL_DIR" sh
else
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$INSTALL_DIR" sh
  # add user-local bin to PATH if not already present
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -q "export PATH=\"$INSTALL_DIR:\$PATH\"" "$rc" 2>/dev/null; then
      printf n# uvnexport PATH=%s:/Users/sagar/.pi/agent/bin:/Users/sagar/.bun/bin:/Users/sagar/.railway/bin:/Users/sagar/.local/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/pkg/env/global/bin:/opt/homebrew/bin:/Applications/Ghostty.app/Contents/MacOSn "$INSTALL_DIR" >> "$rc"
      ok "added $INSTALL_DIR to PATH in $(basename "$rc")"
    fi
  done
fi

ok "uv installed ${D}$(uv --version)${R}"

step "Installing uvx"
# uvx is installed alongside uv by the same installer
if command -v uvx &> /dev/null; then
  ok "uvx ${D}$(uvx --version)${R}"
else
  warn "uvx not found — try opening a new shell"
fi

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}uv --version${R} to verify"
echo ""
