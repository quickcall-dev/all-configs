#!/usr/bin/env bash
set -e

trap 'echo ""; fail "Interrupted"; exit 130' INT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh" || { echo "Error: lib/common.sh not found" >&2; exit 1; }

ensure_uv() {
    if command -v uv &>/dev/null; then
        return 0
    fi

    if [[ -f "$ROOT_DIR/uv/install.sh" ]]; then
        step "uv not found — installing"
        bash "$ROOT_DIR/uv/install.sh"
        ok "uv installed"
    else
        fail "uv not found and installer missing"
        exit 1
    fi

    export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"
}

# Direct install mode: ./install.sh tmux nvim
if [[ $# -gt 0 ]]; then
    for mod in "$@"; do
        if [[ -f "$ROOT_DIR/${mod}/install.sh" ]]; then
            bash "$ROOT_DIR/${mod}/install.sh"
        else
            fail "Unknown module: $mod"
            exit 1
        fi
    done
    exit 0
fi

# Interactive TUI mode
ensure_uv
cd "$ROOT_DIR"
uv run --python 3.12 --with textual python3 -m tui
