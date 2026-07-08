#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

FONT_VERSION="v3.2.1"
FONT_NAME="Meslo"
ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_NAME}.zip"

step "Ensuring font dependencies"
ensure_cmd unzip unzip
if ! command -v fc-cache &> /dev/null; then
    warn "fontconfig not found — installing"
    if [[ "$PLATFORM" == "mac" ]]; then
        ensure_cmd brew brew
        brew install fontconfig
    else
        sudo apt-get update -qq && sudo apt-get install -y -qq fontconfig
    fi
    if command -v fc-cache &> /dev/null; then
        ok "fontconfig installed"
    else
        warn "fontconfig install may have failed - continuing without font cache refresh"
    fi
else
    ok "fontconfig"
fi

step "Installing ${FONT_NAME} Nerd Font"

if [[ "$PLATFORM" == "mac" ]]; then
    FONT_DIR="$HOME/Library/Fonts"
else
    FONT_DIR="$HOME/.local/share/fonts"
fi

mkdir -p "$FONT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

step "Downloading ${FONT_NAME} Nerd Font"
curl -fsSL "$ZIP_URL" -o "$TMP_DIR/${FONT_NAME}.zip"

step "Extracting fonts"
unzip -q "$TMP_DIR/${FONT_NAME}.zip" -d "$TMP_DIR/fonts"

step "Copying fonts to ${FONT_DIR}"
find "$TMP_DIR/fonts" -maxdepth 1 -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp {} "$FONT_DIR/" \;

if [[ "$PLATFORM" == "linux" ]]; then
    step "Refreshing font cache"
    if command -v fc-cache &> /dev/null; then
        fc-cache -fv "$FONT_DIR"
    else
        warn "fc-cache not found — font cache not refreshed"
    fi
fi

ok "${FONT_NAME} Nerd Font installed"
