#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"

step "Installing Node.js (npm + npx)"

# Prefer nvm-managed node when available (e.g. Vast.ai images)
if [[ -s "/opt/nvm/nvm.sh" ]]; then
    export NVM_DIR="/opt/nvm"
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    ok "nvm detected ${D}$(nvm --version)${R}"

    if ! nvm ls "v24" &>/dev/null; then
        warn "nvm node 24 not found — installing latest LTS"
        nvm install --lts
    fi
    nvm alias default "v24" &>/dev/null || true

    # Ensure node/npm/npx are on PATH for the rest of this shell
    export PATH="$NVM_DIR/versions/node/v24.19.0/bin:$PATH"
    ok "node ${D}$(node --version) → $(command -v node)${R}"
    ok "npm ${D}$(npm --version)${R}"
    ok "npx ${D}$(npx --version)${R}"

    # Persist nvm load in shell rc files
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [[ -f "$rc" ]] || continue
        if ! grep -Fq "[ -s \"/opt/nvm/nvm.sh\" ]" "$rc" 2>/dev/null; then
            printf '\n# nvm\nexport NVM_DIR="/opt/nvm"\n[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"\n' >> "$rc"
            ok "nvm loader added to $(basename "$rc")"
        fi
    done

    echo ""
    echo -e "  ${GRN}Done!${R} node $(node --version) ready (nvm)"
    echo ""
    exit 0
fi

# Fallback to system package manager
if command -v node &>/dev/null; then
    ok "node ${D}$(node --version) → $(command -v node)${R}"
else
    warn "node not found — installing"
    if [[ "$PLATFORM" == "linux" ]]; then
        pkg_install npm
    else
        pkg_install node
    fi
    ok "node installed ${D}$(node --version)${R}"
fi

if command -v npm &>/dev/null; then
    ok "npm ${D}$(npm --version)${R}"
fi

if command -v npx &>/dev/null; then
    ok "npx ${D}$(npx --version)${R}"
fi

echo ""
echo -e "  ${GRN}Done!${R} node $(node --version) ready"
echo ""
