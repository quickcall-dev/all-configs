#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Bitwarden"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Bitwarden module currently supports macOS only"
    exit 0
fi

brew_install_cask bitwarden

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
