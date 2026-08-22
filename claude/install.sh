#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Claude Code"

if command -v claude &>/dev/null; then
    ok "claude ${D}$(claude --version 2>/dev/null) → $(command -v claude)${R}"
    warn "already installed — run 'claude update' to upgrade"
else
    warn "claude not found — installing"
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code installed"
fi

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}claude${R} to start"
echo -e "  ${D}Login: claude auth login${R}"
echo ""
