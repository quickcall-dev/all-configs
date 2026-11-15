# claude-config tmux shell helpers
# Sourced from ~/.zshrc / ~/.bashrc by tmux/install.sh

# fzf's Homebrew package does not modify shell config automatically. Load its
# completion and Ctrl+R history widget when supported.
if [[ -o interactive ]] 2>/dev/null && command -v fzf >/dev/null 2>&1; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        source <(fzf --zsh)
    elif [[ -n "${BASH_VERSION:-}" ]] && fzf --bash >/dev/null 2>&1; then
        eval "$(fzf --bash)"
    fi
fi

# Wrap `tmux new` / `tmux new-session` / bare `tmux` to auto-name session by CWD.
# Uses -A: attach if session exists, create otherwise (groups under same name per dir).
tmux() {
    local name sanitized
    case "${1:-}" in
        ""|new|new-session)
            # bare `tmux` or `tmux new` without -s → infer name from CWD
            if [[ $# -le 1 ]]; then
                name="${PWD##*/}"
                sanitized="${name//[.: ]/_}"
                command tmux new-session -A -s "$sanitized"
                return $?
            fi
            ;;
    esac
    command tmux "$@"
}
