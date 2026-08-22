# Plan: deploy configs to Vast.ai GPU instance

## Goal
Install all Linux-compatible modules from `all-configs` onto the remote Ubuntu 24.04 GPU container at `151.237.25.234:28220`.

## Constraints
- Remote is an unprivileged Docker container running as `root`.
- `/workspace` is **not** persistent; install into `/root`.
- Default shell on remote is `bash`.
- mac-only modules skipped.
- Use the `vast-ai` SSH key (`~/.ssh/vast-ai`).

## Modules to install (Linux-compatible)
`caveman`, `claude`, `ffmpeg`, `fonts`, `ghostty`, `github`, `hf`, `ncdu`, `node`, `nvim`, `pi`, `skills`, `ssh-keygen`, `statusline`, `superfile`, `tmux`, `uv`, `yt-dlp`, `zoxide`.

## Steps
1. Fix local `uv/install.sh` bug (garbled `printf`).
2. Sync local repo to `/root/all-configs` via `rsync`.
3. Verify remote environment (OS, git, curl, sudo, apt).
4. Run module installers in dependency order:
   - Base tools: `uv`, `node`
   - CLI tools: `zoxide`, `ffmpeg`, `ncdu`, `yt-dlp`, `superfile`, `tmux`
   - Dev tools: `nvim`, `github`, `ssh-keygen`
   - AI agents: `claude`, `pi`, `caveman`, `skills`, `hf`, `statusline`
   - Terminal: `fonts`, `ghostty`
5. Collect public SSH key and git config summary for user.
6. Verify installs (`command -v` checks).
7. Document issues and final state.

## Risks
- `claude.ai/install.sh` may be interactive or require login.
- `nvim` plugin install may fail in headless mode.
- `pi install https://github.com/obra/superpowers` may need credentials or fail.
- `apt-get` may need network or lock.

## Rollback
- Installer scripts back up existing dotfiles before overwriting.
- If a module fails, fix and re-run individually; most are independent.
