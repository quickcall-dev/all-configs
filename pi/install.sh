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

step "Installing Pi"

if command -v pi &> /dev/null; then
  ok "pi ${D}$(pi --version 2>/dev/null | head -1)${R}"
else
  warn "pi not found — installing"
  if ! command -v npm &>/dev/null; then
    warn "npm not found — installing node first"
    bash "$ROOT_DIR/node/install.sh"
  fi
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  export PATH="$HOME/.local/bin:$PATH"
  ok "pi installed ${D}$(pi --version 2>/dev/null | head -1)${R}"
fi

# Ensure pi is on PATH for the rest of this script
export PATH="$HOME/.local/bin:$PATH"

step "Configuring Pi settings"

PI_AGENT_DIR="$HOME/.pi/agent"
mkdir -p "$PI_AGENT_DIR"

backup_file "$PI_AGENT_DIR/settings.json"
cp "$SCRIPT_DIR/settings.json" "$PI_AGENT_DIR/settings.json"
ok "Pi settings ${D}→ ~/.pi/agent/settings.json${R}"

step "Installing Pi packages"

packages=(
  "npm:@tintinweb/pi-subagents"
  "npm:pi-web-access"
  "npm:pi-caveman"
  "https://github.com/obra/superpowers"
)

for pkg in "${packages[@]}"; do
  if pi list 2>/dev/null | grep -q "${pkg#npm:}"; then
    ok "already installed: $pkg"
  else
    pi install "$pkg" --approve 2>&1 | tail -5
    ok "installed: $pkg"
  fi
done

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}pi${R} to start"
echo -e "  ${D}Pi config: ~/.pi/agent/settings.json${R}"
echo ""
