#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing caveman (Claude Code plugin)"

# ─── Requires claude CLI ───

if ! command -v claude &>/dev/null; then
    warn "claude CLI not found — installing Claude first"
    bash "$ROOT_DIR/claude/install.sh"
fi

if ! command -v claude &>/dev/null; then
    fail "claude CLI still not found after install"
    exit 1
fi

if yes | claude plugin marketplace add JuliusBrussee/caveman; then
    ok "caveman marketplace added"
else
    warn "caveman marketplace add failed or already exists"
fi

if yes | claude plugin install caveman@caveman; then
    ok "caveman installed"
else
    warn "caveman plugin install failed; open Claude Code and run plugin install manually"
fi

step "Setting caveman ultra defaults"

CAVEMAN_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caveman"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

mkdir -p "$CAVEMAN_CONFIG_DIR" "$CLAUDE_DIR" "$PI_AGENT_DIR"

cat > "$CAVEMAN_CONFIG_DIR/config.json" <<'JSON'
{
  "defaultMode": "ultra"
}
JSON
ok "Claude caveman default ${D}→ ultra${R}"

printf 'ultra\n' > "$CLAUDE_DIR/.caveman-active"
ok "Claude caveman active flag ${D}→ ultra${R}"

cat > "$PI_AGENT_DIR/caveman.json" <<'JSON'
{
  "defaultLevel": "ultra",
  "showStatus": true
}
JSON
ok "Pi caveman default ${D}→ ultra${R}"

echo ""
echo -e "  ${GRN}Done!${R} Caveman defaults to ${CYN}ultra${R} in Claude and Pi"
echo -e "  ${D}Stop: /caveman off or 'normal mode'${R}"
echo ""
