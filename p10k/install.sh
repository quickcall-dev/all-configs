#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Powerlevel10k"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "p10k module currently supports macOS only"
    exit 0
fi

if command -v brew &>/dev/null; then
    if ! brew list powerlevel10k &>/dev/null 2&gt;1; then
        brew install powerlevel10k
    fi
    ok "powerlevel10k installed"
else
    warn "Homebrew not found; skipping powerlevel10k install"
    exit 0
fi

DEST="$HOME/.p10k.zsh"
backup_file "$DEST"
cp "$SCRIPT_DIR/p10k.zsh" "$DEST"
ok "p10k config ${D}→ ~/.p10k.zsh${R}"

ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]]; then
    if ! grep -q "powerlevel10k/powerlevel10k.zsh-theme" "$ZSHRC"; then
        {
            echo ""
            echo "# Enable Powerlevel10k"
            echo "source \"$(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme\""
            echo "[[ -f ~/.p10k.zsh ]] \u0026\u0026 source ~/.p10k.zsh"
        } >> "$ZSHRC"
        ok "p10k sourced in ${D}~/.zshrc${R}"
    else
        ok "p10k already sourced in ${D}~/.zshrc${R}"
    fi
else
    warn "~/.zshrc not found; add the powerlevel10k source manually"
fi

echo ""
echo -e "  ${GRN}Done!${R} Restart Zsh or run ${CYN}exec zsh${R}"
echo ""
