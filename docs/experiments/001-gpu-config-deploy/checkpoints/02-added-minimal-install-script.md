# Added minimal install script

```mermaid
graph LR
    A[Full config install was slow/debug-heavy] --> B[Create install-minimal.sh]
    B --> C[Fix nvm/Node 24 path + Debian fd/bat aliases]
    C --> D[Test on live GPU container]
    D --> E[Commit + push to all-configs repo]
```

## What
- Created `install-minimal.sh` at repo root for a headless Linux/GPU container.
- Script installs the essential subset:
  `uv`, `node` (nvm 24), `zoxide`, `ffmpeg`, `ncdu`, `yt-dlp`, `tmux`,
  `github`, `ssh-keygen`, `superfile`, `nvim`, `claude`, `pi`, `caveman`,
  `hf`, `statusline`, `fonts`, `ghostty`.
- Added early `fd-find`/`bat` install + symlinks so `fd` and `bat` exist.
- Added `jq` install before `statusline`.
- Tested idempotently on the already-provisioned Vast.ai container; it completed without errors.

## Key Takeaways
- `install-minimal.sh` takes a single command: `./install-minimal.sh -n "Name" -e email@example.com`.
- It auto-detects `/opt/nvm` and forces Node 24 before any npm-based installs.
- Debian binary aliases are handled automatically, so dotfile configs work out of the box.
- Fresh-container time estimate: ~8–12 minutes; re-run on same container: ~3–5 minutes.

## Issues
- None new. The script avoided the earlier Node 18 and `fd`/`bat` naming traps by design.

## Decisions
- Kept the script at repo root rather than as a module, so it is discoverable and runnable immediately after cloning.
- Did not include mac-only modules or heavier GUI apps (vscode, zed, etc.).
- Did not include the full `skills` QuickCall install because it fails under global install; the Pi system skills are still covered by the full `skills/install.sh` if needed.

## Next
- Commit and push the changes (`install-minimal.sh`, `node/install.sh`, `uv/install.sh`, `zoxide/install.sh`, `docs/experiments/`).
- Use on a fresh Vast.ai container to validate first-boot timing.
- Consider adding a `--full` flag to reuse the same script for the complete module set.
