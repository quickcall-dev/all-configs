# karabiner

Local Karabiner-Elements config for this repo.

## Install

```bash
./karabiner/install.sh
```

This syncs the `karabiner/` directory to `~/.config/karabiner/karabiner_scripts/` and installs `karabiner.json` to `~/.config/karabiner/karabiner.json`.

---

## Keymap

### CAPS LOCK REMAPPING

| From | To | Description |
|------|-----|-------------|
| `Caps Lock` | `Ctrl+Shift+Option+Cmd` (Super) | Caps Lock becomes a hyper/super key |

### APPLICATION SHORTCUTS

| Shortcut | Action |
|----------|--------|
| `Caps + B` | Open/switch to **Brave Browser** |
| `Caps + C` | Open/switch to **Claude** |
| `Caps + D` | Open/switch to **Zed** |
| `Caps + F` | Open/switch to **Finder** |
| `Caps + G` | Open/switch to **Google Chrome** |
| `Caps + L` | Clear terminal (sends `Ctrl + L`) |
| `Caps + M` | Open/switch to **WhatsApp** |
| `Caps + N` | Open/switch to **Presentify** |
| `Caps + O` | Open/switch to **Obsidian** |
| `Caps + S` | Open/switch to **Slack** |
| `Caps + T` | Open/switch to **Ghostty** |
| `Caps + W` | Open/switch to **WhatsApp Web** |

### FN KEY REMAPPING

| From | To | Description |
|------|-----|-------------|
| `Fn` (built-in keyboard) | `Left Control` | Fn key acts as Left Control |

### CONTROL KEY BEHAVIOR

| From | To | Description |
|------|-----|-------------|
| `Left Control` (pressed alone) | `Escape` | Control becomes Escape when tapped |
| `Left Control` (with other keys) | `Control` | Normal Control function when held |
| `Right Control` (pressed alone) | `Escape` | Control becomes Escape when tapped |
| `Right Control` (with other keys) | `Control` | Normal Control function when held |

### OPTION/COMMAND SWAP (Keychron only)

| From | To |
|------|-----|
| `Left Option` | `Left Command` |
| `Left Command` | `Left Option` |
| `Right Option` | `Right Command` |
| `Right Command` | `Right Option` |

### VIM-STYLE NAVIGATION (HJKL)

#### Basic Navigation

| Shortcut | Action |
|----------|--------|
| `Ctrl + H` | Left Arrow |
| `Ctrl + J` | Down Arrow |
| `Ctrl + K` | Up Arrow |
| `Ctrl + L` | Right Arrow |

#### Word-Level Movement

| Shortcut | Action |
|----------|--------|
| `Option + H` | Move left by word |
| `Option + J` | Move down by word |
| `Option + K` | Move up by word |
| `Option + L` | Move right by word |

#### Line-Level Movement

| Shortcut | Action |
|----------|--------|
| `Ctrl + Cmd + H` | Move to line start |
| `Ctrl + Cmd + J` | Move to document end |
| `Ctrl + Cmd + K` | Move to document start |
| `Ctrl + Cmd + L` | Move to line end |

#### Selection (Basic)

| Shortcut | Action |
|----------|--------|
| `Ctrl + Shift + H` | Select left |
| `Ctrl + Shift + J` | Select down |
| `Ctrl + Shift + K` | Select up |
| `Ctrl + Shift + L` | Select right |

#### Selection (Word-Level)

| Shortcut | Action |
|----------|--------|
| `Option + Shift + H` | Select word left |
| `Option + Shift + J` | Select word down |
| `Option + Shift + K` | Select word up |
| `Option + Shift + L` | Select word right |

#### Selection (Line-Level)

| Shortcut | Action |
|----------|--------|
| `Ctrl + Cmd + Shift + H` | Select to line start |
| `Ctrl + Cmd + Shift + J` | Select to document end |
| `Ctrl + Cmd + Shift + K` | Select to document start |
| `Ctrl + Cmd + Shift + L` | Select to document end |

### DELETE KEY MAPPINGS

| Shortcut | Action |
|----------|--------|
| `Ctrl + D` | Forward delete (single character) |

### MOUSE SHORTCUTS

| From | To | Description |
|------|-----|-------------|
| `Right Shift` (pressed alone) | Right Mouse Click | Quick right-click |
| `Right Shift` (with other keys) | `Shift` | Normal Shift function |
| `Escape` | Left Mouse Click | |

---

## Troubleshooting: Keychron K3 Pro modifier weirdness

Recurring issue: left Option and left Command can appear swapped, or Caps Lock can stop behaving like super. This may look like a Karabiner config problem, but evidence from 2026-07-17 showed no Karabiner swap, no `hidutil` mapping, and no macOS modifier mapping.

What happened:
- Caps Lock briefly registered as real `caps_lock` instead of the super key.
- Left Option and left Command appeared swapped on the Keychron K3 Pro.
- Karabiner config was loaded and correct.
- Mac/Windows switch testing did not immediately fix it.
- Visiting `https://usevia.app`, authorizing the Keychron K3 Pro, and testing the keys made the issue suddenly resolve.

Likely cause: Keychron firmware or layer state gets stuck or stale. VIA connection appears to refresh or resync the keyboard layer state. Root cause is not fully confirmed.

If this recurs:
1. Open `https://usevia.app`.
2. Authorize and connect the Keychron K3 Pro.
3. Open Configure -> Keymap.
4. Check Mac layer bottom row near Space. Expected order: `LCTL LOPT LCMD Space` or `LCTL LALT LGUI Space`.
5. Test physical Option and Command in Karabiner EventViewer.
6. If needed, toggle the keyboard Mac/Windows switch once and return to Mac.

Do not assume Karabiner config is wrong until EventViewer, `hidutil`, and macOS modifier settings are checked.

---

## Key Symbols Reference

| Symbol | Key |
|--------|-----|
| `⌘` | Command |
| `⌃` | Control |
| `⌥` | Option/Alt |
| `⇧` | Shift |
| `⇪` | Caps Lock |
| `⎋` | Escape |
| `⌦` | Delete (Forward) |
| `⌫` | Delete (Backward) |
| `←` `→` `↑` `↓` | Arrow Keys |
