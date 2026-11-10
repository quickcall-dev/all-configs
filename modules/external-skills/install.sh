#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing external UI skills (hallmark, taste, impeccable)"

if ! command -v npx &>/dev/null; then
    warn "npx not found — installing node first"
    bash "$ROOT_DIR/modules/node/install.sh"
fi

AGENTS="--agent claude-code --agent codex --agent pi"

# hallmark — anti-AI-slop design skill
npx --yes skills add nutlope/hallmark $AGENTS -g -y

# taste — design taste skill
npx --yes skills add leonxlnx/taste-skill --skill design-taste-frontend $AGENTS -g -y

# impeccable — has its own installer
npx impeccable install --scope=global --yes

ok "External UI skills installed"

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
