# Karabiner Config

Local Karabiner-Elements config for this repo. Karabiner-Elements is macOS only.

## Install / Sync

```bash
./karabiner/install.sh
```

This syncs `karabiner/` to `~/.config/karabiner/karabiner_scripts/` and installs `karabiner.json` to `~/.config/karabiner/karabiner.json` (the live config Karabiner reads), then relaunches Karabiner-Elements.

If you edit configs by hand instead, keep these in sync:

1. The modular file in this directory (e.g. `app_launchers.json`)
2. `karabiner.json` in this directory (merged copy)
3. The live config at `~/.config/karabiner/karabiner.json`

Karabiner watches the live config and reloads automatically (see `~/.local/share/karabiner/log/console_user_server.log` for `core_configuration is updated`).

## Keymap

### Caps Lock

| From | To | Description |
|------|-----|-------------|
| `Caps Lock` | `Ctrl+Shift+Option+Cmd` (super) | Caps Lock becomes a hyper key |

### Application shortcuts

| Shortcut | Action |
|----------|--------|
| `Caps + B` | Open/switch to **Brave Browser** |
| `Caps + C` | Open/switch to **Visual Studio Code** |
| `Caps + D` | Open/switch to **Zed** |
| `Caps + F` | Open/switch to **Finder** |
| `Caps + G` | Open/switch to **ChatGPT** |
| `Caps + L` | Clear terminal (sends `Ctrl + L`) |
| `Caps + M` | Open/switch to **WhatsApp** |
| `Caps + N` | Open/switch to **Presentify** |
| `Caps + O` | Open/switch to **Obsidian** |
| `Caps + S` | Open/switch to **Slack** |
| `Caps + T` | Open/switch to **Ghostty** |
| `Caps + W` | Open/switch to **WhatsApp Web** |

### Modifier behavior

| From | To | Description |
|------|-----|-------------|
| `Fn` (built-in keyboard) | `Left Control` | Fn key acts as Left Control |
| `Left Control` (tapped) | `Escape` | Control becomes Escape when tapped alone |
| `Left Control` (held) | `Control` | Normal Control when used with other keys |
| `Right Control` (tapped) | `Escape` | Same as above, right side |
| `Right Control` (held) | `Control` | Same as above, right side |
| `Right Shift` (tapped) | Right Mouse Click | Quick right-click |
| `Right Shift` (held) | `Shift` | Normal Shift when used with other keys |

### Option/Command swap (Keychron K3 Pro only)

Device-scoped `simple_modifications` on the Keychron (`vendor_id: 13364`), applied in firmware order (emitted codes are pre-swap):

| From | To |
|------|-----|
| `Left Command` | `Left Option` |
| `Left Option` | `Left Command` |
| `Right Command` | `Right Option` |
| `Right Option` | `Right Command` |

Do **not** make this a global swap — it would break the MacBook built-in keyboard. See [troubleshooting.md](./troubleshooting.md) for why.

### Vim-style navigation (HJKL)

#### Basic movement

| Shortcut | Action |
|----------|--------|
| `Ctrl + H` | Left Arrow |
| `Ctrl + J` | Down Arrow |
| `Ctrl + K` | Up Arrow |
| `Ctrl + L` | Right Arrow |

#### Word-level movement

| Shortcut | Action |
|----------|--------|
| `Option + H/J/K/L` | Move by word left/down/up/right |

#### Line/document movement

| Shortcut | Action |
|----------|--------|
| `Ctrl + Cmd + H` | Move to line start |
| `Ctrl + Cmd + J` | Move to document end |
| `Ctrl + Cmd + K` | Move to document start |
| `Ctrl + Cmd + L` | Move to line end |

#### Selection

| Shortcut | Action |
|----------|--------|
| `Ctrl + Shift + H/J/K/L` | Select left/down/up/right |
| `Option + Shift + H/J/K/L` | Select word left/down/up/right |
| `Ctrl + Cmd + Shift + H` | Select to line start |
| `Ctrl + Cmd + Shift + J` | Select to document end |
| `Ctrl + Cmd + Shift + K` | Select to document start |
| `Ctrl + Cmd + Shift + L` | Select to line end |

### Delete / mouse

| Shortcut | Action |
|----------|--------|
| `Ctrl + D` | Forward delete (single character) |
| `Escape` | Left Mouse Click |

## Key symbols

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

## Files

| File | Purpose |
|------|---------|
| `karabiner.json` | Merged config, installed to live config by `install.sh` |
| `app_launchers.json` | Modular: app shortcuts (Caps+letter) |
| `vim_arrow_keys.json` | Modular: HJKL navigation |
| `rename_caps_lock_to_super.json` | Modular: Caps Lock -> super |
| `remap_caps_lock_shift_super.json` | Modular: Caps+Shift escape variant |
| `remap_escape_to_control.json` | Modular: Esc -> Ctrl, tap for Escape |
| `fn_to_control.json` | Modular: Fn -> Left Control |
| `custom_delete_mapping.json` | Modular: Ctrl+D forward delete |
| `right_shift_mouse_click.json` | Modular: Right Shift tap -> right click |
| `swap_esc_delete.json` | Modular: swap Esc/Delete |
| `install.sh` | Syncs repo -> live config, relaunches Karabiner |
| `keychron-modifier-swap.sh` | Helper for Keychron device entries |
| `troubleshooting.md` | Keychron modifier/Caps incident log + debug playbook |
| `agents.md` | Context for AI agents editing this config |
