# Superfile (spf) Cheat Sheet

Your current setup. macOS config: `~/Library/Application Support/superfile/`
(hotkeys: `hotkeys.toml`, settings: `config.toml`)

Launch: `spf` · Quit: `q` or `esc` · Help in app: `?`

---

## Moving Around

| Key | Action |
|---|---|
| `j` / `k` or ↓ / ↑ | move cursor down / up |
| `h` or ← or `backspace` | parent directory |
| `enter` / `l` / → | open file or folder |
| `pgup` / `pgdn` | page up / down |
| `/` | search current directory (type to filter) |
| `z` | zoxide jump — global smart dir jump |
| `.` | show / hide dotfiles |
| `o` | sort menu (name / size / date) |
| `R` | reverse sort order |

## Panels (split views)

| Key | Action |
|---|---|
| `ctrl+n` | new file panel |
| `w` | close current panel |
| `tab` / `L` | next panel |
| `shift+left` / `H` | previous panel |
| `N` | split panel |

## Focus Other Areas

| Key | Action |
|---|---|
| `s` | sidebar (pinned dirs) — press again to go back |
| `m` | metadata panel |
| `p` | process bar (copy progress etc.) |
| `f` | toggle file preview |
| `F` | toggle footer panels |
| `P` | pin / unpin current folder to sidebar |

## File Operations

Works on file under cursor, or all selected files in select mode.

| Key | Action |
|---|---|
| `n` | **new file** (add `/` at end of name = new folder) |
| `ctrl+r` | rename |
| `ctrl+c` | copy |
| `ctrl+x` | cut |
| `ctrl+v` | paste |
| `ctrl+d` / `delete` | delete → Trash |
| `D` | delete permanently (NO undo) |
| `ctrl+a` | compress (zip) |
| `ctrl+e` | extract archive |

> Copy/cut items show in **clipboard panel** (bottom right).
> Progress shows in **process panel** (bottom left).

## Select Mode (bulk ops — like vim visual mode)

| Key | Action |
|---|---|
| `v` | enter / exit select mode |
| `enter` / `L` | select / deselect item under cursor |
| `J` / `shift+↓` | select while moving down |
| `K` / `shift+↑` | select while moving up |
| `A` | select all in directory |

Then use file ops above (`ctrl+c`, `ctrl+d`, ...) on the selection.

## Editor (nvim)

| Key | Action |
|---|---|
| `e` | open file in nvim |
| `E` | open current directory in nvim |

## Command Bars

| Key | Action |
|---|---|
| `:` | **shell mode** — run any terminal command in current dir (`:git status`) |
| `>` | spf mode — `cd <PATH>`, `open <PATH>`, `split`; supports `~`, `${VAR}`, `$(cmd)` |
| `esc` / `ctrl+c` | close the bar |

## Misc

| Key | Action |
|---|---|
| `ctrl+p` | copy file path to clipboard |
| `c` | copy current directory path |
| `Q` | quit AND cd shell to this dir |
| `?` | full hotkey list in app |

---

## Common Workflows

**Copy files between two folders (no commands):**
1. `ctrl+n` new panel → go to destination
2. `tab` back → select files (`v` + `J`)
3. `ctrl+c` → `tab` → `ctrl+v`

**Delete several files:**
`v` → move `j` (auto-marks) or `J` to extend → `ctrl+d`

**Jump to a project, edit it:**
`z` → type project name → `enter` → `E` (nvim opens dir)

**New folder:**
`n` → type `myfolder/` → `enter`

**Run a quick command:**
`:make test` or `:git status` → `esc`

## Shell Setup Notes

- `zoxide` installed + enabled (`zoxide_support = true`). It learns dirs
  as you `cd` in terminal. Seed it: `z add ~/projects ~/Downloads`
- Editor = `$EDITOR` = `nvim` (already set)
- Trash delete needs terminal Full Disk Access:
  System Settings → Privacy & Security → Full Disk Access → enable your terminal
