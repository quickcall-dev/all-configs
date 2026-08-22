#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

step "Installing statusline"

# Check jq
if ! command -v jq &>/dev/null; then
    fail "jq required — brew install jq / apt install jq"
    exit 1
fi

mkdir -p "$CLAUDE_DIR"

# Copy files
cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
ok "statusline.sh ${D}→ ~/.claude/${R}"

cp "$ROOT_DIR/hooks/turn-counter.sh" "$CLAUDE_DIR/turn-counter.sh"
chmod +x "$CLAUDE_DIR/turn-counter.sh"
ok "turn-counter.sh ${D}→ ~/.claude/${R}"

# Merge into settings.json
if [[ -f "$SETTINGS_FILE" ]]; then
    cp "$SETTINGS_FILE" "$CLAUDE_DIR/settings.json.bak"
    existing=$(cat "$SETTINGS_FILE")
else
    existing="{}"
fi

updated=$(echo "$existing" | jq '
  .statusLine = {
    "type": "command",
    "command": ($home + "/.claude/statusline-command.sh")
  } |
  .hooks.Stop = (
    [(.hooks.Stop // [])[] | select(.hooks[0].command | test("turn-counter\\.sh$") | not)] +
    [{"hooks": [{"type": "command", "command": ($home + "/.claude/turn-counter.sh")}]}]
  )
' --arg home "$HOME")

echo "$updated" > "$SETTINGS_FILE"
ok "settings.json ${D}(merged)${R}"

# Verify
all_good=true
[[ -x "$CLAUDE_DIR/statusline-command.sh" ]] || all_good=false
[[ -x "$CLAUDE_DIR/turn-counter.sh" ]] || all_good=false
settings_ok=$(jq 'has("statusLine") and has("hooks")' "$SETTINGS_FILE" 2>/dev/null)
[[ "$settings_ok" == "true" ]] || all_good=false

if [[ "$all_good" == true ]]; then
    ok "all checks passed"
else
    warn "installed with issues"
fi

echo ""
echo -e "  ${D}preview:${R}  ${BLU}my-project${R}${D}/${R}${GRN}main${R}  ${D}session${R} ${GRN} 2%${R} ${D}4h 50m${R}  ${D}ctx${R} ${GRN}5%${R}  ${D}T#${R}${CYN}3${R}"
echo -e "          ${MAG}opus[1M]${R}       ${D}weekly${R}  ${YLW}60%${R} ${D}2d 15h${R}  ${GRN}o low${R}"
echo -e "  ${D}restart claude code to activate${R}"
echo ""
