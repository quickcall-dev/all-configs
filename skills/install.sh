#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing QuickCall skills"

# ─── Requires npx ───

if ! command -v npx &>/dev/null; then
    warn "npx not found — installing node first"
    bash "$ROOT_DIR/node/install.sh"
fi

npx skills add https://github.com/quickcall-dev/skills --yes --global
ok "QuickCall skills installed"

# ─── Pi system skills ───

step "Installing Pi system skills"

PI_SKILLS_DIR="$HOME/.pi/agent/skills"
AGENTS_SKILLS_DIR="$HOME/.agents/skills"

mkdir -p "$AGENTS_SKILLS_DIR" "$PI_SKILLS_DIR"

for skill_dir in "$SCRIPT_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/SKILL.md" ]] || continue

    skill_name="$(basename "$skill_dir")"

    # skip if it is a known non-skill directory (defensive)
    case "$skill_name" in
        node_modules|lib|scripts|references) continue ;;
    esac

    # copy skill into ~/.agents/skills
    rsync -a --delete "$skill_dir" "$AGENTS_SKILLS_DIR/$skill_name/"

    # symlink into ~/.pi/agent/skills
    target="../../../.agents/skills/$skill_name"
    if [[ -L "$PI_SKILLS_DIR/$skill_name" ]]; then
        rm "$PI_SKILLS_DIR/$skill_name"
    fi
    ln -sf "$target" "$PI_SKILLS_DIR/$skill_name"

    ok "Pi skill: $skill_name"
done

echo ""
echo -e "  ${GRN}Done!${R} QuickCall skills ready in Claude Code and Pi"
echo ""
