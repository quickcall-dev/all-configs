# karabiner

Local Karabiner-Elements config for this repo.

## Shortcuts

Caps Lock acts as super key.

App launchers:
- `Caps+g` Google Chrome
- `Caps+b` Brave Browser
- `Caps+d` Zed
- `Caps+s` Slack
- `Caps+t` Ghostty
- `Caps+w` WhatsApp Web
- `Caps+m` WhatsApp desktop
- `Caps+o` Obsidian

Other mappings:
- `Caps+l` clears terminal in supported terminal apps
- `Ctrl` alone -> `Esc`
- `Ctrl/Option/Cmd` with `h/j/k/l` for nav remaps

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

## Install

```bash
./karabiner/install.sh
```

Installer now syncs this repo's `karabiner/` dir into `~/.config/karabiner/karabiner_scripts/` and installs `karabiner/karabiner.json` to `~/.config/karabiner/karabiner.json`.
