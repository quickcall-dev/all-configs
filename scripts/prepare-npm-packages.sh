#!/usr/bin/env bash
# Build the publishable npm package directory (single package — the launcher
# downloads the platform binary from the matching GitHub Release on install).
# Usage: scripts/prepare-npm-packages.sh <version> <output-dir>
set -euo pipefail

VERSION="${1:?version required}"
OUTPUT_DIR="${2:?output directory required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/bin" "$OUTPUT_DIR/runtime"
cp "$ROOT/packages/npm/bin/all-configs.js" "$OUTPUT_DIR/bin/all-configs.js"
cp "$ROOT/packages/npm/README.md" "$OUTPUT_DIR/README.md"
chmod +x "$OUTPUT_DIR/bin/all-configs.js"
cp -R "$ROOT/modules" "$ROOT/lib" "$ROOT/allconfigs" "$OUTPUT_DIR/runtime/"
cp "$ROOT/install.sh" "$OUTPUT_DIR/runtime/install.sh"
find "$OUTPUT_DIR/runtime" -name __pycache__ -type d -prune -exec rm -rf {} +
find "$OUTPUT_DIR/runtime" -name .DS_Store -type f -delete

cat > "$OUTPUT_DIR/package.json" <<EOF
{
  "name": "@quickcall/all-configs",
  "version": "$VERSION",
  "description": "Modular developer environment installer with an interactive OpenTUI interface",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/quickcall-dev/all-configs.git"
  },
  "homepage": "https://github.com/quickcall-dev/all-configs",
  "bugs": "https://github.com/quickcall-dev/all-configs/issues",
  "bin": {
    "all-configs": "bin/all-configs.js"
  },
  "scripts": {
    "postinstall": "node bin/all-configs.js --ensure-binary"
  },
  "engines": {
    "node": ">=18"
  },
  "files": ["bin", "runtime", "README.md"]
}
EOF

echo "Prepared npm package in $OUTPUT_DIR"
