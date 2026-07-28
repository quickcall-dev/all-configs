#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Moshi"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Moshi module currently supports macOS only"
    exit 0
fi

# mosh is a prerequisite for moshi-hook's SSH/Mosh access
ensure_cmd mosh

# Add the custom tap and install the moshi-hook formula
if command -v brew &>/dev/null; then
    if ! brew tap | grep -q "^rjyo/moshi$"; then
        step "Tapping rjyo/moshi"
        NONINTERACTIVE=1 CI=1 brew tap rjyo/moshi
    fi
    brew_install_formula moshi-hook
else
    fail "Homebrew not found; cannot install Moshi"
    exit 1
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
echo -e "  ${YLW}Next step:${R} run ${B}moshi-hook host setup${R} to pair this host."
echo ""
