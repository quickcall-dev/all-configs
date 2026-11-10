# sagarsrc — personal shell aliases & functions

# ll: detailed listing — eza (dirs first, colors, sizes, git status)
if command -v eza >/dev/null 2>&1; then
    alias ll='eza -l --group-directories-first --git --icons=auto'
    alias la='eza -la --group-directories-first --git --icons=auto'
else
    alias ll='ls -lhG'
fi

# reload: re-source the running shell's rc file
if [[ -n "$ZSH_VERSION" ]]; then
    alias reload='source ~/.zshrc'
elif [[ -n "$BASH_VERSION" ]]; then
    alias reload='source ~/.bashrc'
fi

# vi/vim -> neovim
if command -v nvim >/dev/null 2>&1; then
    alias vi='nvim'
    alias vim='nvim'
fi

# ckdir: create a directory (with parents) and cd into it
ckdir() {
    if [[ $# -eq 0 ]]; then
        echo "usage: ckdir <directory>" >&2
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}
