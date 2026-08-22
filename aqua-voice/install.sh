#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Aqua Voice"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Aqua Voice module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    brew_install_cask aqua-voice
else
    warn "Homebrew not found; skipping Aqua Voice app install"
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
