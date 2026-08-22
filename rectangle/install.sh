#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Rectangle"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Rectangle module currently supports macOS only"
    exit 0
fi

brew_install_cask rectangle

CONFIG_SRC="$SCRIPT_DIR/RectangleConfig.json"
if [[ -f "$CONFIG_SRC" ]]; then
    step "Installing Rectangle JSON config"
    python3 - "$CONFIG_SRC" <<'PY'
import json
import subprocess
import sys

config_path = sys.argv[1]
with open(config_path, "r", encoding="utf-8") as f:
    config = json.load(f)

bundle_id = config.get("bundleId", "com.knollsoft.Rectangle")

def run(args):
    subprocess.run(["defaults", "write", bundle_id, *args], check=True)

for key, value in config.get("defaults", {}).items():
    if "bool" in value:
        run([key, "-bool", "true" if value["bool"] else "false"])
    elif "int" in value:
        run([key, "-int", str(value["int"])])
    elif "float" in value:
        run([key, "-float", str(value["float"])])
    elif "string" in value:
        run([key, "-string", str(value["string"])])
    elif value == {}:
        run([key, "-dict"])

for key, value in config.get("shortcuts", {}).items():
    if "keyCode" in value and "modifierFlags" in value:
        run([
            key,
            "-dict",
            "keyCode", "-int", str(value["keyCode"]),
            "modifierFlags", "-int", str(value["modifierFlags"]),
        ])
PY
    ok "Rectangle JSON config installed"
    warn "Restart Rectangle after install so shortcuts reload"
    warn "Grant Accessibility permission to Rectangle on first launch if macOS asks"
else
    warn "RectangleConfig.json not found; skipping"
fi

echo ""
echo -e "  ${GRN}Done!${R}"
echo ""
