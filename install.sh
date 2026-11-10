#!/usr/bin/env bash
# all-configs entry point (macOS and Linux only).
#
#   ./install.sh               interactive TUI
#   ./install.sh tmux nvim     install the named modules directly, no TUI
#   ./install.sh --list        list modules available on this platform
set -e

trap 'echo ""; fail "Interrupted"; exit 130' INT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# common.sh exits on anything other than Darwin/Linux
source "$ROOT_DIR/lib/common.sh" || { echo "Error: lib/common.sh not found" >&2; exit 1; }

PYTHON_VERSION="3.12"
TEXTUAL_SPEC="textual==8.2.*"

ensure_uv() {
    # uv may already be installed but not on PATH in this shell
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    command -v uv &>/dev/null && return 0

    [[ -f "$ROOT_DIR/uv/install.sh" ]] || { fail "uv not found and uv/install.sh missing"; exit 1; }
    step "uv not found — installing"
    bash "$ROOT_DIR/uv/install.sh"
    command -v uv &>/dev/null || { fail "uv install finished but uv is not on PATH"; exit 1; }
    ok "uv installed ${D}$(command -v uv)${R}"
}

list_modules() {
    local toml name platforms
    for toml in "$ROOT_DIR"/*/module.toml; do
        name="$(basename "$(dirname "$toml")")"
        platforms="$(grep -E '^platforms' "$toml" || true)"
        if [[ "$platforms" == *"\"$PLATFORM\""* ]]; then echo "$name"; fi
    done
}

case "${1:-}" in
    -h|--help)
        sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    -l|--list)
        list_modules
        exit 0
        ;;
esac

# Direct install mode: ./install.sh tmux nvim
if [[ $# -gt 0 ]]; then
    for mod in "$@"; do
        # module names are plain directory names; reject paths like ../x
        if [[ ! "$mod" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || [[ ! -f "$ROOT_DIR/$mod/install.sh" ]]; then
            fail "Unknown module: $mod (see ./install.sh --list)"
            exit 1
        fi
    done
    for mod in "$@"; do
        bash "$ROOT_DIR/$mod/install.sh"
    done
    exit 0
fi

# Interactive TUI mode needs a real terminal
if [[ ! -t 0 || ! -t 1 ]]; then
    fail "The TUI needs an interactive terminal. Use ./install.sh <module>... instead."
    exit 1
fi

ensure_uv
cd "$ROOT_DIR"
exec uv run --quiet --no-project --python "$PYTHON_VERSION" --with "$TEXTUAL_SPEC" python3 -m tui
