#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

usage() {
  cat << USAGE
Usage: ${0##*/} [options]

Options:
  -h, --help  Show this help
USAGE
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    *) fail "Unknown option: $1"; exit 1 ;;
  esac
done

step "Installing Bun"

if command -v bun &>/dev/null; then
  ok "bun ${D}$(bun --version)${R}"
else
  warn "bun not found — installing via official installer"
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
fi

for rc in "$HOME/.profile" "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || touch "$rc"
  python3 - "$rc" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text().splitlines() if path.exists() else []
out = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == '# bun':
        i += 1
        while i < len(lines) and (
            lines[i].startswith('export BUN_INSTALL=') or
            lines[i].startswith('export PATH="$HOME/.bun/bin:$PATH"') or
            lines[i].startswith('export PATH="$BUN_INSTALL/bin:$PATH"') or
            lines[i].startswith('case ":$PATH:" in') or
            lines[i].startswith('  *":$HOME/.bun/bin:"*) ;;') or
            lines[i].startswith('  *) export PATH="$HOME/.bun/bin:$PATH" ;;') or
            lines[i].startswith('esac') or
            lines[i].strip() == ''
        ):
            i += 1
        continue
    out.append(line)
    i += 1
text = '\n'.join(out).rstrip() + '\n\n# bun\ncase ":$PATH:" in\n  *":$HOME/.bun/bin:"*) ;;\n  *) export PATH="$HOME/.bun/bin:$PATH" ;;\nesac\n'
path.write_text(text)
PY
  ok "ensured ~/.bun/bin PATH in $(basename "$rc")"
done

ok "bun ${D}$(bun --version)${R}"

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
