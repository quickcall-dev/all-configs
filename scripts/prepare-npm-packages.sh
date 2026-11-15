#!/usr/bin/env bash
# Build publishable npm package directories from release binaries.
# Usage: scripts/prepare-npm-packages.sh <version> <binary-dir> <output-dir>
set -euo pipefail

VERSION="${1:?version required}"
BINARY_DIR="${2:?binary directory required}"
OUTPUT_DIR="${3:?output directory required}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/main/bin" "$OUTPUT_DIR/main/runtime"
cp "$ROOT/packages/npm/bin/all-configs.js" "$OUTPUT_DIR/main/bin/all-configs.js"
cp "$ROOT/packages/npm/README.md" "$OUTPUT_DIR/main/README.md"
chmod +x "$OUTPUT_DIR/main/bin/all-configs.js"
cp -R "$ROOT/modules" "$ROOT/lib" "$ROOT/allconfigs" "$OUTPUT_DIR/main/runtime/"
cp "$ROOT/install.sh" "$OUTPUT_DIR/main/runtime/install.sh"
find "$OUTPUT_DIR/main/runtime" -name __pycache__ -type d -prune -exec rm -rf {} +
find "$OUTPUT_DIR/main/runtime" -name .DS_Store -type f -delete

optional_dependencies=""
first=true

for target in darwin-arm64 darwin-x64 linux-arm64 linux-x64; do
  source_file="$BINARY_DIR/all-configs-tui-$target"
  compressed_file="$source_file.gz"
  if [[ ! -f "$source_file" && ! -f "$compressed_file" ]]; then
    echo "Skipping unavailable target: $target" >&2
    continue
  fi

  package_name="@quickcall/all-configs-$target"
  package_dir="$OUTPUT_DIR/$target"
  mkdir -p "$package_dir/bin"
  if [[ -f "$source_file" ]]; then
    cp "$source_file" "$package_dir/bin/all-configs"
  else
    gzip -dc "$compressed_file" > "$package_dir/bin/all-configs"
  fi
  chmod +x "$package_dir/bin/all-configs"

  os="${target%-*}"
  cpu="${target##*-}"
  cat > "$package_dir/package.json" <<EOF
{
  "name": "$package_name",
  "version": "$VERSION",
  "description": "Platform binary for @quickcall/all-configs ($target)",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/quickcall-dev/all-configs.git"
  },
  "os": ["$os"],
  "cpu": ["$cpu"],
  "files": ["bin/all-configs"]
}
EOF

  if [[ "$first" == true ]]; then
    first=false
  else
    optional_dependencies+=","
  fi
  optional_dependencies+=$'\n    '"\"$package_name\": \"$VERSION\""
done

cat > "$OUTPUT_DIR/main/package.json" <<EOF
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
  "engines": {
    "node": ">=18"
  },
  "files": ["bin", "runtime", "README.md"],
  "optionalDependencies": {$optional_dependencies
  }
}
EOF

echo "Prepared npm packages in $OUTPUT_DIR"
