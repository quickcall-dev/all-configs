#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing VS Code"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "VS Code module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    brew_install_cask visual-studio-code
else
    warn "Homebrew not found; skipping VS Code app install"
fi

DEST_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$DEST_DIR"

for file in settings.json keybindings.json tasks.json; do
    [[ -f "$SCRIPT_DIR/$file" ]] || continue
    backup_file "$DEST_DIR/$file"
    cp "$SCRIPT_DIR/$file" "$DEST_DIR/$file"
    ok "$file ${D}→ ~/Library/Application Support/Code/User/$file${R}"
done

echo ""
echo -e "  ${GRN}Done!${R} Restart VS Code to apply"
echo ""
