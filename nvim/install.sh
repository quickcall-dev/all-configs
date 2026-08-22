#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing neovim config (LazyVim)"

# Ensure build tools for native plugins
step "Ensuring build tools"
if ! command -v gcc &> /dev/null || ! command -v make &> /dev/null; then
    warn "gcc/make not found — installing build-essential"
    if [[ "$PLATFORM" == "mac" ]]; then
        brew_install_formula gcc
        brew_install_formula make
    else
        sudo apt-get update -qq && sudo apt-get install -y -qq build-essential
    fi
    ok "build tools installed"
else
    ok "gcc and make present"
fi

# Ensure nvim is installed
if ! command -v nvim &>/dev/null; then
    warn "nvim not found — installing"
    if [[ "$PLATFORM" == "mac" ]]; then
        brew_install_formula neovim
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

# fuzzy finder + search tools (picker deps: fzf-lua/telescope, grep, file finding)
step "Ensuring search tools"
for tool in fzf fd ripgrep imagemagick; do
    if pkg_check "$tool"; then
        ok "$tool present"
    else
        pkg_install "$tool" && ok "$tool installed" || warn "$tool install failed"
    fi
done

# tree-sitter
if ! command -v tree-sitter &>/dev/null; then
    if [[ "$PLATFORM" == "mac" ]]; then
        brew_install_formula tree-sitter
    elif command -v npm &>/dev/null; then
        warn "tree-sitter-cli not found — installing"
        npm install -g tree-sitter-cli
        ok "tree-sitter-cli installed"
    else
        warn "tree-sitter-cli not found (npm not available — skipping)"
    fi
else
    ok "tree-sitter-cli"
fi

# Install config into Neovim's actual stdpath("config"). Snap builds may use
# /home/$USER/.config even when $HOME differs.
NVIM_DIR="$(nvim --headless '+lua io.write(vim.fn.stdpath("config"))' +qa 2>/dev/null || true)"
[[ -n "$NVIM_DIR" ]] || NVIM_DIR="$HOME/.config/nvim"
mkdir -p "$NVIM_DIR"

backup_file "$NVIM_DIR"

# Copy all files
rsync -a "$SCRIPT_DIR/" "$NVIM_DIR/" \
  --exclude install.sh \
  --exclude README.md \
  --exclude '._*' \
  --exclude '.DS_Store'
find "$NVIM_DIR" -name '._*' -delete 2>/dev/null || true
find "$NVIM_DIR" -name '.DS_Store' -delete 2>/dev/null || true
ok "nvim config ${D}→ $NVIM_DIR/${R}"

# Install plugins
step "Installing nvim plugins"
plugin_log="$(mktemp)"
if nvim --headless "+Lazy! restore" +qa >"$plugin_log" 2>&1; then
    if grep -Eq "E492:|Failed to load" "$plugin_log"; then
        warn "plugin bootstrap hit config errors — open nvim manually"
        tail -20 "$plugin_log" || true
    elif grep -q "mason.nvim] Neovim exited while the following packages were installing" "$plugin_log"; then
        warn "plugins bootstrapped; some Mason packages continue on first interactive open"
    else
        ok "plugins installed"
    fi
else
    warn "open nvim manually — plugins will auto-install"
    tail -20 "$plugin_log" || true
fi
rm -f "$plugin_log"

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}nvim${R} to start"
echo -e "  ${D}Theme: Rose Pine Dawn  |  Leader: Space${R}"
echo ""
