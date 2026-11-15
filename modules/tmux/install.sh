#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing tmux config (oh-my-tmux)"

ensure_cmd tmux

ensure_cmd git

# ─── oh-my-tmux ───

OMT_DIR="$HOME/.oh-my-tmux"
if [[ -d "$OMT_DIR" ]]; then
    ok "oh-my-tmux already cloned"
else
    git clone --depth 1 --single-branch https://github.com/gpakosz/.tmux.git "$OMT_DIR"
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

if [[ -L "$LOCAL_DEST" ]]; then
    # migrate a symlink (possibly pointing into a since-deleted repo path,
    # e.g. an npm runtime dir) to a stable regular file
    rm "$LOCAL_DEST"
    cp "$SCRIPT_DIR/.tmux.conf.local" "$LOCAL_DEST"
    ok ".tmux.conf.local ${D}→ ~/.tmux.conf.local (copied — user edits are safe)${R}"
elif [[ -e "$LOCAL_DEST" ]]; then
    ok ".tmux.conf.local kept (existing file)${R}"
else
    cp "$SCRIPT_DIR/.tmux.conf.local" "$LOCAL_DEST"
    ok ".tmux.conf.local ${D}→ ~/.tmux.conf.local (copied)${R}"
fi

# ─── Shell helpers (auto-name tmux sessions from CWD) ───
# Copy to a stable per-user location: rc files must not reference the repo
# (which may live in an npm runtime dir under a temp path).

HELPERS_SRC="$SCRIPT_DIR/shell-helpers.sh"
HELPERS_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/all-configs/tmux-shell-helpers.sh"
mkdir -p "$(dirname "$HELPERS_DEST")"
cp "$HELPERS_SRC" "$HELPERS_DEST"
ok "shell helpers ${D}→ $HELPERS_DEST${R}"

SNIPPET="[ -f \"$HELPERS_DEST\" ] && source \"$HELPERS_DEST\"  # claude-config tmux helpers"

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    # Replace stale paths from older repo layouts instead of treating any
    # marker as current.
    tmp="$(mktemp)"
    grep -Fv "claude-config tmux helpers" "$rc" > "$tmp" || true
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    printf '\n%s\n' "$SNIPPET" >> "$rc"
    ok "shell helpers ${D}→ $(basename "$rc")${R}"
done

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}tmux${R} to start"
echo -e "  ${D}Prefix: Ctrl+b  |  Reload: prefix r${R}"
echo ""
