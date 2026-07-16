#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Karabiner-Elements"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Karabiner-Elements is macOS only; skipping"
    exit 0
fi

if command -v karabiner_cli &>/dev/null || [[ -d "/Applications/Karabiner-Elements.app" ]]; then
    ok "Karabiner-Elements already installed"
else
    warn "Karabiner-Elements not found; installing via brew cask"
    brew_install_cask karabiner-elements
    ok "Karabiner-Elements installed"
fi

step "Installing karabiner config"

CONFIG_DIR="$HOME/.config/karabiner"
REPO_DEST="$CONFIG_DIR/karabiner_scripts"
SRC_JSON="$SCRIPT_DIR/karabiner.json"
DEST_JSON="$CONFIG_DIR/karabiner.json"

mkdir -p "$CONFIG_DIR"

warn "Quitting Karabiner-Elements briefly while syncing config"
osascript -e 'tell application "Karabiner-Elements" to quit' 2>/dev/null || true
pkill -x "Karabiner-Elements" 2>/dev/null || true
pkill -f "karabiner_console_user_server" 2>/dev/null || true
sleep 2

backup_file "$DEST_JSON"

if [[ "$SCRIPT_DIR" != "$REPO_DEST" ]]; then
    step "Syncing repo copy to $REPO_DEST"
    mkdir -p "$REPO_DEST"
    rsync -a --delete --exclude='.git' "$SCRIPT_DIR/" "$REPO_DEST/"
    ok "Repo synced"
fi

cp "$SRC_JSON" "$DEST_JSON"
ok "karabiner.json installed"

open -a "Karabiner-Elements"
ok "Karabiner-Elements relaunched"

echo ""
echo -e "  ${GRN}Done!${R} Karabiner-Elements is running with local repo config"
echo -e "  ${D}Config: $SRC_JSON${R}"
echo ""
