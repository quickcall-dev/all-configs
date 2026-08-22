#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh" || { echo "Error: lib/common.sh not found" >&2; exit 1; }

MODULE="${1:-}"
if [[ -z "$MODULE" ]]; then
    fail "Usage: ${0##*/} <module>"
    exit 1
fi

TOML="$ROOT_DIR/$MODULE/module.toml"
if [[ ! -f "$TOML" ]]; then
    fail "Unknown module: $MODULE"
    exit 1
fi

PKG=""
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^package\s*=\s*\"(.*)\"$ ]] && PKG="${BASH_REMATCH[1]}"
done < "$TOML"

if [[ -z "$PKG" ]]; then
    PKG="$MODULE"
fi

step "Uninstalling $MODULE ($PKG)"
pkg_uninstall "$PKG"
ok "$MODULE uninstalled"
