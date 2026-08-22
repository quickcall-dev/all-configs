#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Tailscale"

if command -v tailscale &>/dev/null; then
    ok "tailscale ${D}$(tailscale version 2>/dev/null | head -1 || command -v tailscale)${R}"
    echo ""
    echo -e "  ${GRN}Done!${R} Run ${CYN}tailscale up${R} to authenticate"
    echo ""
    exit 0
fi

if [[ "$PLATFORM" == "mac" ]]; then
    brew_install_cask tailscale
else
    warn "tailscale not found — installing via official Linux installer"
    curl -fsSL https://tailscale.com/install.sh | sudo bash
fi

ok "tailscale ${D}$(tailscale version 2>/dev/null | head -1 || command -v tailscale)${R}"

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}tailscale up${R} to authenticate"
echo ""
