#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing AlDente"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "AlDente module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    brew_install_cask aldente
else
    warn "Homebrew not found; skipping AlDente app install"
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
