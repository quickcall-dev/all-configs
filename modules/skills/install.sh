#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

# Every skill published in quickcall-dev/skills.
ALL_SKILLS=(
    diagram-creator
    doc
    html-creator
    markdown-to-pdf
    onion-explainer
    product-ui-kit
    python-code-dev
    python-notebook-dev
    technical-manual
)

# Usage:
#   install.sh                      → install all skills
#   install.sh doc markdown-to-pdf  → install only the named skills
skills=("$@")
if [[ ${#skills[@]} -eq 0 ]]; then
    skills=("${ALL_SKILLS[@]}")
fi

for s in "${skills[@]}"; do
    if [[ ! " ${ALL_SKILLS[*]} " == *" $s "* ]]; then
        fail "Unknown skill: $s"
        echo "  Available: ${ALL_SKILLS[*]}"
        exit 1
    fi
done

step "Installing skills: ${skills[*]} (quickcall-dev/skills)"

if ! command -v npx &>/dev/null; then
    warn "npx not found — installing node first"
    bash "$ROOT_DIR/modules/node/install.sh"
fi
command -v npx &>/dev/null || { fail "npx still not on PATH after node install"; exit 1; }

AGENTS="--agent claude-code --agent codex --agent pi"

install_skill() {
    local s="$1" attempt
    # npx package fetches and GitHub clones can fail transiently on remote
    # hosts — retry before giving up.
    for attempt in 1 2 3; do
        if npx --yes skills add quickcall-dev/skills --skill "$s" $AGENTS -g -y; then
            return 0
        fi
        [[ $attempt -lt 3 ]] && { warn "$s: attempt $attempt/3 failed — retrying"; sleep 3; }
    done
    return 1
}

failed=()
for s in "${skills[@]}"; do
    install_skill "$s" || failed+=("$s")
done

if [[ ${#failed[@]} -gt 0 ]]; then
    fail "Failed to install: ${failed[*]}"
    exit 1
fi

ok "Skills installed from source: ${skills[*]}"

echo ""
echo -e "  ${GRN}Done!${R} Skills installed from source; no local skill copies are used"
echo ""
