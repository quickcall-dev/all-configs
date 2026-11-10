# Tmux Setup

Minimal, vim-style tmux config powered by [oh-my-tmux](https://github.com/gpakosz/.tmux).

## Install

```bash
./install.sh tmux
```

## What's included

### Framework
- **oh-my-tmux** — self-contained tmux framework with Powerline status bar
- Pastel sage theme (warm cream, zero harsh colors)
- Status bar at top with session name, pane number, hostname

### Key bindings

| Key | Action |
|-----|--------|
| `prefix \|` | Split horizontal (side-by-side) |
| `prefix _` | Split vertical (stacked) |
| `prefix h/j/k/l` | Navigate panes (repeatable) |
| `C-h/j/k/l` | Smart pane nav + vim passthrough |
| `prefix C-h` | Previous window |
| `prefix C-l` | Next window |
| `prefix Tab` | Last window |
| `prefix 1-9` | Jump to window |
| `prefix j` | Swap pane down |
| `prefix k` | Swap pane up |
| `prefix H/J/K/L` | Resize pane (2 cells) |
| `prefix Escape` | Enter copy mode |
| `v` / `V` | Visual select / line select |
| `y` | Copy to clipboard |
| `prefix q` | Kill pane (confirm) |
| `prefix Q` | Kill window (confirm) |
| `prefix M` | Maximize pane to new window |
| `prefix C-f` | Find session |
| `prefix C-c` | New session |
| `prefix r` | Reload config |
| `prefix U` | URL scanner |
| `prefix F` | PathPicker |

### Misc
- History: 100,000 lines
- Mouse: always on (click tabs to switch windows)
- 1-based window/pane indexing
- Silent (no bell, no activity alerts)
- Ghostty-compatible extended keys
