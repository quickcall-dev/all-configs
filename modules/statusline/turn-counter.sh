#!/usr/bin/env bash
# Increment turn counter per session
# Counter lives at /tmp/claude-turns-<session_id>.txt
# Resumed sessions (claude --resume) keep the same session_id,
# so the counter picks up where it left off.
# Files in /tmp survive until reboot.
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TURN_FILE="/tmp/claude-turns-${SESSION_ID}.txt"
CURRENT=$(cat "$TURN_FILE" 2>/dev/null || echo "0")
echo $(( CURRENT + 1 )) > "$TURN_FILE"
