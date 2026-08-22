#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing source-managed skills"

if ! command -v npx &>/dev/null; then
    warn "npx not found — installing node first"
    bash "$ROOT_DIR/node/install.sh"
fi

# Install only selected skills from upstream sources. No local skill copies.
npx --yes skills add https://github.com/jimliu/baoyu-skills --skill baoyu-youtube-transcript --agent claude-code --agent pi -g -y
npx --yes skills add quickcall-dev/skills --skill markdown-to-pdf --agent claude-code --agent pi -g -y
npx --yes skills add quickcall-dev/skills --skill doc --agent claude-code --agent pi -g -y
npx --yes skills add nutlope/hallmark --agent claude-code --agent pi -g -y
npx --yes skills add https://github.com/openclaw/openclaw --skill tmux --agent claude-code --agent pi -g -y
npx impeccable install --scope=global --yes
ok "Selected skills installed from source"

echo ""
echo -e "  ${GRN}Done!${R} Skills installed from source; no local skill copies are used"
echo ""
