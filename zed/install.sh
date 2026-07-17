#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Zed"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Zed module currently supports macOS only"
    exit 0
fi

if [[ -d "/Applications/Zed.app" ]]; then
    ok "Zed app already installed"
elif command -v brew &>/dev/null; then
    brew_install_cask zed
else
    warn "Homebrew not found; skipping Zed app install"
fi

DEST="$HOME/.config/zed/settings.json"
mkdir -p "$(dirname "$DEST")"

backup_file "$DEST"
cp "$SCRIPT_DIR/settings.json" "$DEST"
chmod 600 "$DEST"
ok "zed settings ${D}→ ~/.config/zed/settings.json${R}"

if [[ -d "$HOME/.config/Zed" && "$HOME/.config/Zed" != "$HOME/.config/zed" ]]; then
    ALT_DEST="$HOME/.config/Zed/settings.json"
    mkdir -p "$(dirname "$ALT_DEST")"
    backup_file "$ALT_DEST"
    cp "$SCRIPT_DIR/settings.json" "$ALT_DEST"
    chmod 600 "$ALT_DEST"
    ok "zed settings ${D}→ ~/.config/Zed/settings.json${R}"
fi

echo ""
echo -e "  ${GRN}Done!${R} Restart Zed or open new terminal tab to apply"
echo -e "  ${D}Terminal font: MesloLGS Nerd Font Mono${R}"
echo ""
