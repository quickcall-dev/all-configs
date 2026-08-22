#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Presentify from the Mac App Store"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Presentify module currently supports macOS only"
    exit 0
fi

if ! command -v mas &>/dev/null; then
    step "Installing mas (Mac App Store CLI)"
    brew_install_formula mas
fi

step "Installing Presentify (ID: 1507246666)"
mas install 1507246666

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
