#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Codex"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Codex module currently supports macOS only"
    exit 0
fi

if command -v curl &>/dev/null; then
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    ok "Codex installed"
else
    fail "curl is required to install Codex"
    exit 1
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
