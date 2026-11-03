#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing sagarsrc"

SRC="$SCRIPT_DIR/sagarsrc"
DEST="$HOME/.sagarsrc"

# Symlink ~/.sagarsrc -> repo file
if [[ -L "$DEST" && "$(readlink "$DEST")" == "$SRC" ]]; then
    ok "~/.sagarsrc already linked"
else
    if [[ -e "$DEST" && ! -L "$DEST" ]]; then
        warn "Existing ~/.sagarsrc found — backing up to ~/.sagarsrc.bak"
        mv "$DEST" "$DEST.bak"
    fi
    ln -sfn "$SRC" "$DEST"
    ok "~/.sagarsrc → $SRC"
fi

# Make sure the shell sources it
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -Fq '.sagarsrc' "$rc" 2>/dev/null; then
        printf '\n# sagarsrc — personal aliases\n[[ -f ~/.sagarsrc ]] && source ~/.sagarsrc\n' >> "$rc"
        ok "sourcing added to $(basename "$rc")"
    else
        ok "~/.sagarsrc already sourced in $(basename "$rc")"
    fi
done

ok "sagarsrc installed — restart your shell or run: source ~/.sagarsrc"
