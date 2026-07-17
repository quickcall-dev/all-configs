#!/usr/bin/env bash
set -e

trap 'echo ""; fail "Interrupted"; exit 130' INT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh" || { echo "Error: lib/common.sh not found" >&2; exit 1; }

GROUP_ORDER=(Browsers Media Editors Terminals Shell Runtimes AI Comms DevTools Fonts System Utilities Extras)

MODULE_ORDER=(browsers spotify vlc nvim vscode zed ghostty tmux zoxide p10k node uv claude codex pi caveman skills slack github docker hf ssh-keygen fonts karabiner aldente betterdisplay raycast bitwarden rectangle shortcat statusline presentify keycastr aqua-voice)

module_group() {
    case "$1" in
        betterdisplay|aldente|raycast|bitwarden|rectangle|shortcat|presentify|aqua-voice) echo "Utilities" ;;
        keycastr) echo "System" ;;
        browsers) echo "Browsers" ;;
        vlc|spotify) echo "Media" ;;
        nvim|vscode|zed) echo "Editors" ;;
        ghostty|tmux) echo "Terminals" ;;
        zoxide|p10k) echo "Shell" ;;
        karabiner) echo "System" ;;
        node|uv) echo "Runtimes" ;;
        claude|pi|caveman|skills|codex) echo "AI" ;;
        slack) echo "Comms" ;;
        github|hf|ssh-keygen|docker) echo "DevTools" ;;
        fonts) echo "Fonts" ;;
        statusline) echo "Extras" ;;
        *) echo "Other" ;;
    esac
}

ensure_brew() {
    if command -v brew &>/dev/null; then
        return 0
    fi

    for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [[ -x "$brew_path" ]]; then
            PATH="$(dirname "$brew_path"):$PATH"
            return 0
        fi
    done

    if ! sudo -n true 2>/dev/null; then
        fail "Homebrew install requires passwordless sudo. Install it manually: https://brew.sh"
        exit 1
    fi

    step "Homebrew not found — installing"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [[ -x "$brew_path" ]]; then
            PATH="$(dirname "$brew_path"):$PATH"
            break
        fi
    done
    ok "Homebrew installed"
}

ensure_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi

    ensure_brew
    step "Installing Gum via Homebrew"
    brew_install_formula gum
    ok "Gum installed"
}

run_ui() {
    ensure_gum

    export GUM_CHOOSE_CURSOR_FOREGROUND="#f38ba8"
    export GUM_CHOOSE_SELECTED_PREFIX_FOREGROUND="#f38ba8"
    export GUM_CHOOSE_UNSELECTED_PREFIX_FOREGROUND="#6c7086"
    export GUM_CHOOSE_SELECTED_FOREGROUND="#000000"
    export GUM_CHOOSE_HEADER_FOREGROUND="#000000"
    export GUM_CONFIRM_PROMPT_FOREGROUND="#000000"
    export GUM_CONFIRM_SELECTED_FOREGROUND="#000000"
    export GUM_CONFIRM_UNSELECTED_FOREGROUND="#000000"
    export GUM_SPIN_SPINNER_FOREGROUND="#f38ba8"
    export GUM_SPIN_TITLE_FOREGROUND="#000000"

    gum style \
        --foreground "#000000" \
        --border-foreground "#f38ba8" \
        --border rounded \
        --align center \
        --width 60 \
        --padding "2 4" \
        "all-configs installer" \
        "macOS dotfiles & developer tooling"

    declare -a module_names=()
    declare -a module_descs=()
    declare -a module_groups=()

    for child in "$ROOT_DIR"/*/; do
        child="${child%/}"
        name=$(basename "$child")
        [[ -f "$child/install.sh" && -f "$child/module.toml" ]] || continue

        mod_desc=""
        platforms=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^description\ =\ \"(.*)\"$ ]] && mod_desc="${BASH_REMATCH[1]}"
            [[ "$line" =~ ^platforms\ =\ \[(.*)\]$ ]] && platforms="${BASH_REMATCH[1]}"
        done < "$child/module.toml"

        [[ "$platforms" == *"$PLATFORM"* ]] || continue
        [[ -z "$mod_desc" ]] && mod_desc="$name"

        module_names+=("$name")
        module_descs+=("$mod_desc")
        module_groups+=("$(module_group "$name")")
    done

    if [[ ${#module_names[@]} -eq 0 ]]; then
        warn "No modules available for $PLATFORM"
        exit 0
    fi

    declare -a ordered_names=()
    declare -a ordered_descs=()
    declare -a ordered_groups=()

    for mod in "${MODULE_ORDER[@]}"; do
        for i in "${!module_names[@]}"; do
            [[ "${module_names[$i]}" == "$mod" ]] || continue
            ordered_names+=("${module_names[$i]}")
            ordered_descs+=("${module_descs[$i]}")
            ordered_groups+=("${module_groups[$i]}")
            break
        done
    done

    for i in "${!module_names[@]}"; do
        local found=0
        for mod in "${MODULE_ORDER[@]}"; do
            [[ "${module_names[$i]}" == "$mod" ]] && { found=1; break; }
        done
        if [[ "$found" -eq 0 ]]; then
            ordered_names+=("${module_names[$i]}")
            ordered_descs+=("${module_descs[$i]}")
            ordered_groups+=("${module_groups[$i]}")
        fi
    done

    module_names=("${ordered_names[@]}")
    module_descs=("${ordered_descs[@]}")
    module_groups=("${ordered_groups[@]}")

    max_len=0
    for name in "${module_names[@]}"; do
        len=${#name}
        (( len > max_len )) && max_len=$len
    done

    declare -a display_items=()
    for i in "${!module_names[@]}"; do
        display_items+=("$(printf "%-${max_len}s | %s" "${module_names[$i]}" "${module_descs[$i]}")")
    done

    selected_display=$(gum choose --no-limit \
        --height "${#display_items[@]}" \
        --cursor "> " \
        --selected-prefix "● " \
        --unselected-prefix "○ " \
        --header "Select modules (Tab/Space toggle, Enter confirm)" \
        --selected "*" \
        "${display_items[@]}" || true)

    declare -a selected_modules=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        mod_name=$(echo "$line" | sed 's/ *|.*//')
        mod_name=$(echo "$mod_name" | tr -d ' ')
        [[ -n "$mod_name" ]] && selected_modules+=("$mod_name")
    done <<< "$selected_display"

    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        step "No modules selected"
        exit 0
    fi

    gum confirm "Install ${#selected_modules[@]} module(s)?" || exit 0

    ensure_brew

    declare -a failed=()
    for mod_name in "${selected_modules[@]}"; do
        if ! gum spin --show-output --spinner dot --title "Installing $mod_name" -- bash "$ROOT_DIR/$mod_name/install.sh"; then
            failed+=("$mod_name")
        fi
    done

    echo ""
    if [[ ${#failed[@]} -gt 0 ]]; then
        fail "Finished with failures: ${failed[*]}"
        exit 1
    else
        echo -e "  ${GRN}Done!${R}"
    fi
}

# Direct install mode: ./install.sh tmux nvim
if [[ $# -gt 0 ]]; then
    for mod in "$@"; do
        if [[ -f "$ROOT_DIR/${mod}/install.sh" ]]; then
            bash "$ROOT_DIR/${mod}/install.sh"
        else
            fail "Unknown module: $mod"
            exit 1
        fi
    done
    exit 0
fi

# Interactive TUI mode
run_ui
