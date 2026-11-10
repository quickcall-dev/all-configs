#!/usr/bin/env bash
# Remove packages through the platform package manager.
#
#   lib/uninstall.sh <package>...
#
# Package names come from the [uninstall] table of a module.toml
# (`brew` on macOS, `packages` on Linux); the TUI resolves them.
# Config-only modules have no [uninstall] table and are never passed here,
# so this script cannot delete a tool that a config module merely configures.
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh" || { echo "Error: lib/common.sh not found" >&2; exit 1; }

if [[ $# -eq 0 ]]; then
    fail "Usage: ${0##*/} <package>..."
    exit 1
fi

status=0
for pkg in "$@"; do
    if [[ ! "$pkg" =~ ^[A-Za-z0-9@._+-]+$ ]]; then
        fail "invalid package name: $pkg"
        status=1
        continue
    fi
    step "Uninstalling $pkg"
    if pkg_uninstall "$pkg"; then
        ok "$pkg uninstalled"
    else
        fail "$pkg not uninstalled"
        status=1
    fi
done
exit "$status"
