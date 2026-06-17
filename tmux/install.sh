#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/setup/lib/common.sh"

step "Installing tmux config (oh-my-tmux)"

ensure_cmd tmux

# ─── oh-my-tmux ───

OMT_DIR="$HOME/.oh-my-tmux"
if [[ -d "$OMT_DIR" ]]; then
    ok "oh-my-tmux already cloned"
else
    git clone --single-branch https://github.com/gpakosz/.tmux.git "$OMT_DIR"
    ok "oh-my-tmux cloned"
fi

# ─── Config ───

CONF_DEST="$HOME/.tmux.conf"
LOCAL_DEST="$HOME/.tmux.conf.local"

backup_file "$CONF_DEST"
backup_file "$LOCAL_DEST"

[[ -L "$CONF_DEST" ]] && rm "$CONF_DEST"
ln -sf "$OMT_DIR/.tmux.conf" "$CONF_DEST"
ok "tmux.conf ${D}→ ~/.tmux.conf (symlinked to oh-my-tmux)${R}"

ln -sf "$SCRIPT_DIR/.tmux.conf.local" "$LOCAL_DEST"
ok ".tmux.conf.local ${D}→ ~/.tmux.conf.local (symlinked)${R}"

# ─── Shell helpers (auto-name tmux sessions from CWD) ───

HELPERS_SRC="$SCRIPT_DIR/shell-helpers.sh"
SNIPPET="[ -f \"$HELPERS_SRC\" ] && source \"$HELPERS_SRC\"  # claude-config tmux helpers"

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if ! grep -Fq "claude-config tmux helpers" "$rc" 2>/dev/null; then
        printf '\n%s\n' "$SNIPPET" >> "$rc"
        ok "shell helpers ${D}→ $(basename "$rc")${R}"
    else
        ok "shell helpers already in $(basename "$rc")"
    fi
done

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}tmux${R} to start"
echo -e "  ${D}Prefix: Ctrl+b  |  Reload: prefix r${R}"
echo ""
