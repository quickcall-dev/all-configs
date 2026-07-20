#!/usr/bin/env bash
# Shared helpers for all installers

R='\033[0m' B='\033[1m' D='\033[2m'
GRN='\033[32m' YLW='\033[33m' RED='\033[31m'
CYN='\033[36m' BLU='\033[34m' MAG='\033[35m'

ok()   { printf "  ${GRN}${B}✓${R} %b\n" "$1"; }
warn() { printf "  ${YLW}${B}!${R} %b\n" "$1"; }
fail() { printf "  ${RED}${B}✗${R} %b\n" "$1"; }
step() { printf "\n  ${CYN}${B}→${R} %b\n" "$1"; }

OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="mac" ;;
    Linux)  PLATFORM="linux" ;;
    *)      fail "Unsupported OS: $OS"; exit 1 ;;
esac

pkg_install() {
    local pkg="$1"
    if [[ "$PLATFORM" == "mac" ]]; then
        command -v brew &>/dev/null || { fail "Homebrew not found: https://brew.sh"; return 1; }
        yes | NONINTERACTIVE=1 CI=1 brew install "$pkg"
    else
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$pkg"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "$pkg"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm "$pkg"
        else
            fail "No supported package manager found"; return 1
        fi
    fi
}

pkg_check() {
    local pkg="$1"
    if [[ "$PLATFORM" == "mac" ]]; then
        if command -v brew &>/dev/null; then
            brew list --cask "$pkg" &>/dev/null && return 0
            brew list "$pkg" &>/dev/null && return 0
        fi
    fi
    command -v "$pkg" &>/dev/null && return 0
    if command -v dpkg &>/dev/null && dpkg -l "$pkg" &>/dev/null 2>&1; then
        return 0
    fi
    if command -v rpm &>/dev/null && rpm -q "$pkg" &>/dev/null 2>&1; then
        return 0
    fi
    if command -v pacman &>/dev/null && pacman -Q "$pkg" &>/dev/null 2>&1; then
        return 0
    fi
    return 1
}

pkg_uninstall() {
    local pkg="$1"
    if [[ "$PLATFORM" == "mac" ]]; then
        if command -v brew &>/dev/null; then
            if brew list --cask "$pkg" &>/dev/null 2>&1; then
                yes | NONINTERACTIVE=1 CI=1 brew uninstall --cask "$pkg"
                return 0
            elif brew list "$pkg" &>/dev/null 2>&1; then
                yes | NONINTERACTIVE=1 CI=1 brew uninstall "$pkg"
                return 0
            fi
        fi
    fi
    if command -v apt-get &>/dev/null; then
        sudo apt-get remove -y -qq "$pkg"
    elif command -v dnf &>/dev/null; then
        sudo dnf remove -y "$pkg"
    elif command -v pacman &>/dev/null; then
        sudo pacman -R --noconfirm "$pkg"
    else
        fail "No supported package manager for uninstall"; return 1
    fi
}

ensure_cmd() {
    local cmd="$1" pkg="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd ${D}$(command -v "$cmd")${R}"
        return 0
    else
        warn "$cmd not found — installing"
        pkg_install "$pkg"
        if command -v "$cmd" &>/dev/null; then
            ok "$cmd installed"
        else
            fail "$cmd installation failed"
            return 1
        fi
    fi
}

brew_cask_installed() {
    local name="$1"
    command -v brew &>/dev/null && brew list --cask "$name" &>/dev/null 2>&1
}

brew_formula_installed() {
    local name="$1"
    command -v brew &>/dev/null && brew list "$name" &>/dev/null 2>&1
}

brew_install_cask() {
    local name="$1"
    if brew_cask_installed "$name"; then
        ok "$name already installed"
        return 0
    fi
    step "Installing $name"
    yes | NONINTERACTIVE=1 CI=1 brew install --cask "$name"
    ok "$name installed"
}

brew_install_formula() {
    local name="$1"
    if brew_formula_installed "$name"; then
        ok "$name already installed"
        return 0
    fi
    step "Installing $name"
    yes | NONINTERACTIVE=1 CI=1 brew install "$name"
    ok "$name installed"
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        local bak="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$bak"
        ok "backed up ${D}→ $bak${R}"
    fi
}
