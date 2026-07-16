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

echo ""
echo -e "  ${GRN}Done!${R} Use ${CYN}/caveman${R} in Claude Code to activate"
echo -e "  ${D}Levels: /caveman lite | full | ultra  |  Stop: 'normal mode'${R}"
echo ""
