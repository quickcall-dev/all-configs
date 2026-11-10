#!/usr/bin/env bash
set -e

TEAL='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
skip() { echo -e "  $1 — skipped (not found)"; }

echo ""
echo -e "  ${RED}uninstall${NC}"
echo ""

# ─── Confirm ───

read -p "This will remove tmux config, nvim config, and all plugins. Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# ─── Tmux ───

echo ""
echo -e "${TEAL}→${NC} Removing tmux config"

if [[ -f "$HOME/.tmux.conf" ]] || [[ -L "$HOME/.tmux.conf" ]]; then
    rm "$HOME/.tmux.conf"
    ok "removed ~/.tmux.conf"
else
    skip "~/.tmux.conf"
fi

# Restore backup if one exists
LATEST_BACKUP=$(ls -t "$HOME/.tmux.conf.backup."* 2>/dev/null | head -1)
if [[ -n "$LATEST_BACKUP" ]]; then
    read -p "Restore backup $LATEST_BACKUP? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$LATEST_BACKUP" "$HOME/.tmux.conf"
        ok "restored from $LATEST_BACKUP"
    fi
fi

if [[ -d "$HOME/.tmux/plugins" ]]; then
    rm -rf "$HOME/.tmux/plugins"
    ok "removed tmux plugins"
else
    skip "tmux plugins"
fi

# ─── Neovim ───

echo ""
echo -e "${TEAL}→${NC} Removing neovim config"

if [[ -f "$HOME/.config/nvim/init.lua" ]]; then
    rm "$HOME/.config/nvim/init.lua"
    ok "removed ~/.config/nvim/init.lua"
else
    skip "~/.config/nvim/init.lua"
fi

# Restore backup if one exists
LATEST_NVIM_BACKUP=$(ls -t "$HOME/.config/nvim/init.lua.backup."* 2>/dev/null | head -1)
if [[ -n "$LATEST_NVIM_BACKUP" ]]; then
    read -p "Restore backup $LATEST_NVIM_BACKUP? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$LATEST_NVIM_BACKUP" "$HOME/.config/nvim/init.lua"
        ok "restored from $LATEST_NVIM_BACKUP"
    fi
fi

if [[ -d "$HOME/.local/share/nvim" ]]; then
    rm -rf "$HOME/.local/share/nvim"
    ok "removed nvim plugin data"
else
    skip "nvim plugin data"
fi

if [[ -d "$HOME/.local/state/nvim" ]]; then
    rm -rf "$HOME/.local/state/nvim"
    ok "removed nvim state"
else
    skip "nvim state"
fi

# ─── VS Code / Cursor ───

echo ""
echo -e "${TEAL}→${NC} Cleaning editor settings"

clean_editor_settings() {
    local settings_file="$1"
    local editor_name="$2"

    if [[ ! -f "$settings_file" ]]; then
        skip "$editor_name settings"
        return
    fi

    if ! grep -q "gpuAcceleration" "$settings_file"; then
        skip "$editor_name (no tmux settings found)"
        return
    fi

    local tmp=$(mktemp)
    grep -v '"terminal.integrated.gpuAcceleration"' "$settings_file" \
        | grep -v '"terminal.integrated.profiles\.' \
        | grep -v '"terminal.integrated.defaultProfile\.' \
        > "$tmp" && mv "$tmp" "$settings_file"
    ok "$editor_name tmux settings removed"
}

if [[ "$(uname -s)" == "Darwin" ]]; then
    clean_editor_settings "$HOME/Library/Application Support/Code/User/settings.json" "VS Code"
    clean_editor_settings "$HOME/Library/Application Support/Cursor/User/settings.json" "Cursor"
else
    clean_editor_settings "$HOME/.config/Code/User/settings.json" "VS Code"
    clean_editor_settings "$HOME/.config/Cursor/User/settings.json" "Cursor"
fi

# ─── Done ───

echo ""
echo -e "${GREEN}Done.${NC} Configs and plugins removed."
echo "  Packages (tmux, neovim, fzf) were left installed."
echo ""
