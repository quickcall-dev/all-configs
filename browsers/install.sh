#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing browsers"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Browsers module currently supports macOS only"
    exit 0
fi

if ! command -v brew &>/dev/null; then
    step "Homebrew not found — installing"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed"
else
    ok "Homebrew ${D}$(command -v brew)${R}"
fi

step "Installing Brave"
brew install --cask brave-browser
ok "Brave installed"

step "Installing Google Chrome"
brew install --cask google-chrome
ok "Google Chrome installed"

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
