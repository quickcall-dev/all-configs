#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Tinycast"

if [[ "$PLATFORM" != "mac" ]]; then
    warn "Tinycast module currently supports macOS only"
    exit 0
fi

if ! command -v brew &>/dev/null; then
    fail "Homebrew not found; cannot install Tinycast"
    exit 1
fi

# Third-party tap requires explicit trust first
step "Trusting + tapping abue-ammar/tinycast"
brew trust --tap abue-ammar/tinycast || warn "brew trust failed (may already be trusted)"
if ! brew tap | grep -q "^abue-ammar/tinycast$"; then
    NONINTERACTIVE=1 CI=1 brew tap abue-ammar/tinycast
fi
ok "tap ready"

# Pick the right cask for this macOS version / arch:
#   tinycast            — macOS 26+ (Tahoe), arm64
#   tinycast-sequoia    — macOS 15, arm64
#   tinycast-universal  — Intel (any supported macOS)
step "Installing cask"
macos_major="$(sw_vers -productVersion | cut -d. -f1)"
arch_name="$(uname -m)"
if [[ "$arch_name" == "arm64" && "$macos_major" -ge 26 ]]; then
    cask="abue-ammar/tinycast/tinycast"
elif [[ "$arch_name" == "arm64" ]]; then
    cask="abue-ammar/tinycast/tinycast-sequoia"
else
    cask="abue-ammar/tinycast/tinycast-universal"
fi
ok "selected cask ${D}$cask${R} (macOS $macos_major, $arch_name)"

if brew_cask_installed "${cask##*/}"; then
    ok "tinycast already installed"
else
    NONINTERACTIVE=1 CI=1 brew install --cask "$cask"
    ok "tinycast installed"
fi

# ─── Config ───

step "Linking settings"
CONFIG_DIR="$HOME/.config/tinycast"
mkdir -p "$CONFIG_DIR"
DEST="$CONFIG_DIR/settings.json"

if [[ -L "$DEST" && "$(readlink "$DEST")" == "$SCRIPT_DIR/settings.json" ]]; then
    ok "settings.json already linked"
else
    [[ -f "$DEST" && ! -L "$DEST" ]] && { cp "$DEST" "$DEST.backup.$(date +%Y%m%d_%H%M%S)"; warn "existing settings backed up"; }
    ln -sfn "$SCRIPT_DIR/settings.json" "$DEST"
    ok "settings.json ${D}→ $DEST (symlinked)${R}"
fi

echo ""
echo -e "  ${GRN}Done!${R} Open Tinycast to apply settings"
echo ""
