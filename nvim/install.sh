#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing neovim config (LazyVim)"

# Ensure nvim is installed
if ! command -v nvim &>/dev/null; then
    warn "nvim not found — installing"
    if [[ "$PLATFORM" == "mac" ]]; then
        pkg_install neovim
    else
        if command -v snap &>/dev/null; then
            sudo snap install nvim --classic
        elif command -v apt-get &>/dev/null; then
            sudo apt-get install -y -qq software-properties-common
            sudo add-apt-repository -y ppa:neovim-ppa/unstable
            sudo apt-get update -qq
            sudo apt-get install -y -qq neovim
        else
            pkg_install neovim
        fi
    fi
    ok "nvim installed"
else
    ok "nvim ${D}$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+[^ ]*' | head -1)${R}"
fi

# tree-sitter
if ! command -v tree-sitter &>/dev/null; then
    if command -v npm &>/dev/null; then
        warn "tree-sitter-cli not found — installing"
        sudo npm install -g tree-sitter-cli
        ok "tree-sitter-cli installed"
    else
        warn "tree-sitter-cli not found (npm not available — skipping)"
    fi
else
    ok "tree-sitter-cli"
fi

# Install config
NVIM_DIR="$HOME/.config/nvim"
mkdir -p "$NVIM_DIR"

backup_file "$NVIM_DIR"

# Copy all files
rsync -a "$SCRIPT_DIR/" "$NVIM_DIR/" --exclude install.sh --exclude README.md
ok "nvim config ${D}→ ~/.config/nvim/${R}"

# Install plugins
step "Installing nvim plugins"
nvim --headless "+Lazy! restore" +qa 2>/dev/null && ok "plugins installed" || warn "open nvim manually — plugins will auto-install"

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}nvim${R} to start"
echo -e "  ${D}Theme: Rose Pine Dawn  |  Leader: Space${R}"
echo ""
