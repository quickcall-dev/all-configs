#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing personal skills (quickcall-dev/skills)"

if ! command -v npx &>/dev/null; then
    warn "npx not found — installing node first"
    bash "$ROOT_DIR/node/install.sh"
fi

AGENTS="--agent claude-code --agent codex --agent pi"

# Personal skills from quickcall-dev/skills — no local skill copies
npx --yes skills add quickcall-dev/skills --skill doc $AGENTS -g -y
npx --yes skills add quickcall-dev/skills --skill markdown-to-pdf $AGENTS -g -y
npx --yes skills add quickcall-dev/skills --skill product-ui-kit $AGENTS -g -y
ok "Personal skills installed from source"

echo ""
echo -e "  ${GRN}Done!${R} Skills installed from source; no local skill copies are used"
echo ""
