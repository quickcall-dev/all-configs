#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing shell aliases"

SRC="$SCRIPT_DIR/aliases.sh"
DEST="$HOME/.aliases"

# Symlink ~/.aliases -> repo file
if [[ -L "$DEST" && "$(readlink "$DEST")" == "$SRC" ]]; then
    ok "~/.aliases already linked"
else
    if [[ -e "$DEST" && ! -L "$DEST" ]]; then
        warn "Existing ~/.aliases found — backing up to ~/.aliases.bak"
        mv "$DEST" "$DEST.bak"
    fi
    ln -sfn "$SRC" "$DEST"
    ok "~/.aliases → $SRC"
fi

# Make sure the shell sources it
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -Fq '.aliases' "$rc" 2>/dev/null; then
        printf '\n# shell aliases & functions\n[[ -f ~/.aliases ]] && source ~/.aliases\n' >> "$rc"
        ok "sourcing added to $(basename "$rc")"
    else
        ok "~/.aliases already sourced in $(basename "$rc")"
    fi
done

ok "aliases installed — restart your shell or run: source ~/.aliases"
