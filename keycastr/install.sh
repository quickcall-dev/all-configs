#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing KeyCastr"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "KeyCastr module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    brew_install_cask keycastr
else
    warn "Homebrew not found; skipping KeyCastr app install"
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
