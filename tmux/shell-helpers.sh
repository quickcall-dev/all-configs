# claude-config tmux shell helpers
# Sourced from ~/.zshrc / ~/.bashrc by tmux/install.sh

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
