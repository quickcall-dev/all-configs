#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing superfile (spf)"

if command -v spf &> /dev/null; then
    ok "superfile already installed ${D}$(spf --version 2>/dev/null | head -1)${R}"
else
    if command -v brew &> /dev/null; then
        brew_install_formula superfile
    else
        step "No Homebrew — using official installer"
        bash -c "$(curl -sLo- https://superfile.dev/install.sh)"
    fi
    ok "superfile installed"
fi

# Config path differs per platform
if [[ "$PLATFORM" == "mac" ]]; then
    SPF_DIR="$HOME/Library/Application Support/superfile"
else
    SPF_DIR="$HOME/.config/superfile"
fi

# Run once to generate default config tree (skip if exists)
if [[ ! -d "$SPF_DIR" ]]; then
    step "Generating default config"
    spf --help &>/dev/null || true
    mkdir -p "$SPF_DIR"
fi

step "Installing superfile config"
backup_file "$SPF_DIR/config.toml"
backup_file "$SPF_DIR/hotkeys.toml"
cp "$SCRIPT_DIR/config.toml" "$SPF_DIR/config.toml"
cp "$SCRIPT_DIR/hotkeys.toml" "$SPF_DIR/hotkeys.toml"
ok "config + hotkeys ${D}→ $SPF_DIR${R}"

# zoxide integration (optional but enabled in config)
if ! command -v zoxide &> /dev/null; then
    warn "zoxide not found — 'z' jump disabled until installed (run: ./install.sh zoxide)"
else
    ok "zoxide present ${D}(z jump enabled)${R}"
fi

step "Adding sf alias"
ALIASES_FILE="$HOME/.aliases"
if [[ ! -f "$ALIASES_FILE" ]]; then
    [[ -f "$HOME/.zshrc" ]] && ALIASES_FILE="$HOME/.zshrc" || ALIASES_FILE="$HOME/.bashrc"
fi
if ! grep -Fq 'alias sf=' "$ALIASES_FILE" 2>/dev/null; then
    printf '# superfile\nalias sf="spf"\n' >> "$ALIASES_FILE"
    ok "alias sf ${D}→ $(basename "$ALIASES_FILE")${R}"
else
    ok "alias sf already in $(basename "$ALIASES_FILE")"
fi

echo ""
echo -e "  ${GRN}Done!${R} Run ${CYN}spf${R} to start — press ${CYN}?${R} for hotkeys"
echo -e "  ${D}Cheat sheet: superfile/cheatsheet.md${R}"
echo ""
