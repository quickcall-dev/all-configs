#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Zoom"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Zoom module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    brew_install_cask zoom
else
    warn "Homebrew not found; skipping Zoom app install"
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
