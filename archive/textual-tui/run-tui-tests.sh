#!/usr/bin/env bash
# TUI tests: fake modules in a temp dir, fake $HOME — never touches the real system.
set -e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
exec uv run --quiet --no-project --python 3.12 \
    --with 'textual==8.2.*' --with pytest --with pytest-asyncio \
    python -m pytest -c tests/pytest.ini --rootdir "$ROOT_DIR" "$@"
