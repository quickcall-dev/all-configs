#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Ghostty"

# ─── Install ───

if [[ "$PLATFORM" == "mac" ]]; then
    if command -v ghostty &>/dev/null; then
        ok "ghostty ${D}$(command -v ghostty)${R}"
    else
        warn "ghostty not found — installing via brew cask"
        brew_install_cask ghostty
        ok "ghostty installed"
    fi
else
    warn "Linux: install ghostty manually from https://ghostty.org/download"
fi

# ─── Config ───

CONFIG_TARGETS=(
    "$HOME/.config/ghostty/config"
    "$HOME/.config/ghostty/config.ghostty"
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
)

for DEST in "${CONFIG_TARGETS[@]}"; do
    mkdir -p "$(dirname "$DEST")"
    backup_file "$DEST"
    [[ -L "$DEST" ]] && rm "$DEST"
    ln -sf "$SCRIPT_DIR/config" "$DEST"
    ok "ghostty config ${D}→ $DEST (symlinked)${R}"
done

# ─── Themes ───

THEME_TARGETS=(
    "$HOME/.config/ghostty/themes"
    "$HOME/Library/Application Support/com.mitchellh.ghostty/themes"
)

for THEMES_DEST in "${THEME_TARGETS[@]}"; do
    mkdir -p "$THEMES_DEST"
    for theme in "$SCRIPT_DIR/themes/"*; do
        [[ -f "$theme" ]] || continue
        ln -sf "$theme" "$THEMES_DEST/$(basename "$theme")"
        ok "theme ${D}$(basename "$theme") → $THEMES_DEST/${R}"
    done
done

echo ""
echo -e "  ${GRN}Done!${R} Open Ghostty to apply"
echo -e "  ${D}Theme: catppuccin-macchiato  |  Font: JetBrains Mono 14${R}"
echo ""
