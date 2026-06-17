#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing zoxide"

if command -v zoxide &> /dev/null; then
    ok "zoxide already installed ${D}$(command -v zoxide)${R}"
    exit 0
fi

if command -v brew &> /dev/null; then
    brew install zoxide
elif command -v apt-get &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq zoxide
elif command -v dnf &> /dev/null; then
    sudo dnf install -y zoxide
elif command -v pacman &> /dev/null; then
    sudo pacman -S --noconfirm zoxide
else
    step "No package manager found — using official installer"
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

ok "zoxide installed"

step "Enabling zoxide in shell"

ZOXIDE_INIT='
# zoxide — smarter cd
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi'

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -Fq "zoxide init" "$rc" 2>/dev/null; then
        printf '%s\n' "$ZOXIDE_INIT" >> "$rc"
        ok "zoxide enabled in $(basename "$rc")"
    else
        ok "zoxide already enabled in $(basename "$rc")"
    fi
done
