#!/usr/bin/env bash
# Install (or update) all-configs anywhere: one canonical clone + a released
# single-binary TUI on PATH.
#
#   curl -fsSL https://raw.githubusercontent.com/quickcall-dev/all-configs/main/scripts/install.sh | sh
#
# Environment overrides:
#   ALL_CONFIGS_DIR   where the repo lives      (default ~/.all-configs)
#   ALL_CONFIGS_BIN   where the command lands   (default ~/.local/bin)
#   SKIP_BINARY=1     repo only, run TUI from source with Bun
set -euo pipefail

REPO="https://github.com/quickcall-dev/all-configs.git"
GITHUB="https://github.com/quickcall-dev/all-configs"
DIR="${ALL_CONFIGS_DIR:-$HOME/.all-configs}"
BIN_DIR="${ALL_CONFIGS_BIN:-$HOME/.local/bin}"

say() { printf '\033[0;32m→\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m!\033[0m %s\n' "$*"; }
die() { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ─── repo: clone once, pull after (this is also the updater) ────────────────
if [[ -d "$DIR/.git" ]]; then
  say "updating $DIR"
  git -C "$DIR" pull --ff-only
elif [[ -e "$DIR" ]]; then
  die "$DIR exists but is not a git checkout"
else
  say "cloning $REPO → $DIR"
  git clone "$REPO" "$DIR"
fi

# ─── binary: prefer a GitHub release; fall back to running from source ──────
install_binary() {
  local os arch asset url
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"   # darwin | linux
  arch="$(uname -m)"                              # arm64 | x86_64
  [[ "$arch" == "x86_64" ]] && arch="x64"
  asset="all-configs-tui-${os}-${arch}.gz"
  url="$GITHUB/releases/latest/download/$asset"

  say "downloading $asset"
  mkdir -p "$DIR/bin"
  curl -fsSL --retry 2 "$url" | gunzip > "$DIR/bin/all-configs-tui" || return 1
  chmod +x "$DIR/bin/all-configs-tui"

  mkdir -p "$BIN_DIR"
  ln -sfn "$DIR/bin/all-configs-tui" "$BIN_DIR/all-configs"
  say "linked $BIN_DIR/all-configs"
}

if [[ "${SKIP_BINARY:-0}" != "1" ]]; then
  if ! install_binary; then
    warn "no prebuilt binary for this platform (or download failed)"
    if command -v bun >/dev/null 2>&1; then
      warn "falling back to Bun: the 'all-configs' command will not be installed"
    else
      die "install Bun (https://bun.sh) or SKIP_BINARY=0 with a release available"
    fi
  fi
fi

# ─── probe dependency ────────────────────────────────────────────────────────
command -v uv >/dev/null 2>&1 || warn "uv not found — module detection needs it: https://docs.astral.sh/uv/"

cat <<EOF

done. usage:
  all-configs              TUI (from $BIN_DIR — make sure it is on PATH)
  $DIR/install.sh <mod>    install one module without the TUI
  re-run this script       update repo + binary
EOF
