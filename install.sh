#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh" || { echo "Error: lib/common.sh not found" >&2; exit 1; }

VENV_DIR="$ROOT_DIR/.tmp-install-venv"
PYTHON="$VENV_DIR/bin/python"

python_version_ok() {
    local py="${1:-python3}"
    "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null
}

bootstrap_python() {
    # Prefer uvx: no persistent venv needed
    if command -v uvx &>/dev/null; then
        uvx --python python3.11 --from textual python -m all_configs.tui "$@"
        return 0
    fi

    # Create a temporary venv and install Textual
    if [[ ! -d "$VENV_DIR" ]]; then
        step "Creating temporary installer environment"
        if command -v uv &>/dev/null; then
            uv venv "$VENV_DIR" --python python3.11
        elif command -v python3 &>/dev/null && python_version_ok python3; then
            python3 -m venv "$VENV_DIR"
        else
            fail "Python 3.11+ required. Install Python 3.11+ or uv."
            exit 1
        fi
    fi

    if ! "$PYTHON" -c "import textual" 2>/dev/null; then
        step "Installing Textual TUI"
        "$PYTHON" -m pip install --quiet textual
    fi

    cd "$ROOT_DIR" || { fail "Cannot cd to $ROOT_DIR"; exit 1; }
    "$PYTHON" -m all_configs.tui "$@"
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

bootstrap_python
