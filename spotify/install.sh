#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Spotify"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Spotify module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    brew install --cask spotify
else
    warn "Homebrew not found; skipping Spotify app install"
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
