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
| `Caps + C` | Open/switch to **Visual Studio Code** |
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

Incident date: 2026-10-01.

Symptom:
- Caps Lock stopped behaving like super.
- Physical left Option emitted `left_command`.
- Physical left Command emitted `left_option`.
- Physical right Command emitted `right_option`.
- The MacBook built-in keyboard still behaved correctly.

Root cause found:
- After a Keychron reset/re-pair, macOS/Karabiner no longer saw the keyboard as the old K3 Pro identity:
  - old: `vendor_id: 13364`, `product_id: 560`, product `Keychron K3 Pro`
  - new: `vendor_id: 13364`, `product_id: 640`, product `Keychron Bluetooth Keyboard`
- The new `640` identity reports as both `is_keyboard: true` and `is_pointing_device: true`.
- The config initially added `product_id: 640` with only `is_keyboard: true`, so Karabiner did not fully match that device identity. Caps-to-super then came through as raw `caps_lock`.
- After adding `is_pointing_device: true`, Caps-to-super worked again.
- EventViewer then proved the current Keychron Bluetooth profile itself was emitting swapped modifier codes, so the final fix was a device-specific `simple_modifications` correction scoped only to `vendor_id: 13364`, `product_id: 640`.

Do not add global Command/Option swaps. They will break the built-in MacBook keyboard.

Agent handoff: exact debug path used:

1. Confirm whether this is a Karabiner config change, a macOS native mapping, or keyboard firmware/layer output.

   ```bash
   hidutil property --get UserKeyMapping
   defaults read -g com.apple.keyboard.modifiermapping 2>/dev/null
   jq '.profiles[0].complex_modifications.rules[] | select((.description|ascii_downcase|contains("swap")) or ((.manipulators // []) | tostring | test("left_option|left_command|right_option|right_command")))' ~/.config/karabiner/karabiner.json
   ```

   Evidence from the incident:
   - `hidutil property --get UserKeyMapping` returned `(null)`.
   - `defaults read -g com.apple.keyboard.modifiermapping` returned no mapping.
   - The live config did not have an enabled complex Command/Option swap rule.

2. Compare what macOS sees with what Karabiner sees.

   ```bash
   hidutil list | rg -i 'keychron|karabiner|internal keyboard'
   /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --list-connected-devices
   ```

   Evidence from the incident:
   - `hidutil` showed the external keyboard as `0x3434 0x280 ... Keychron Bluetooth Keyboard`.
   - Karabiner CLI showed:

     ```json
     {
       "device_identifiers": {
         "is_keyboard": true,
         "is_pointing_device": true,
         "product_id": 640,
         "vendor_id": 13364
       },
       "product": "Keychron Bluetooth Keyboard",
       "transport": "Bluetooth"
     }
     ```

   Key realization: the config knew the old Keychron identity `product_id: 560`, but the connected keyboard was now `product_id: 640`. The first attempted `640` entry missed `is_pointing_device: true`, so it still did not match the actual Karabiner device identity correctly.

3. Verify the active profile and whether the Caps rule exists there.

   ```bash
   /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name
   jq '.profiles[] | {name, selected, devices: [.devices[] | select(.identifiers.vendor_id==13364)], caps_rule: [.complex_modifications.rules[] | select(.description=="Remap caps_lock to super") | .description]}' ~/.config/karabiner/karabiner.json
   tail -n 20 ~/.local/share/karabiner/log/console_user_server.log
   ```

   Evidence from the incident:
   - Active profile was `Default profile`.
   - `Remap caps_lock to super` was present.
   - Karabiner reloaded the file successfully after edits, for example `core_configuration is updated`.

4. Use Karabiner-EventViewer as the source of truth for what is happening after Karabiner processing.

   Probe order used:
   - Clear EventViewer.
   - Press physical left Option down/up.
   - Press physical left Command down/up.
   - Press physical right Command down/up.
   - Press physical Caps Lock down/up.
   - Press physical `a` down/up.

   First failing trace showed:
   - physical left Option -> `left_command`
   - physical left Command -> `left_option`
   - physical right Command -> `right_option`
   - physical Caps -> raw `caps_lock`
   - `a` -> `a`

   Interpretation:
   - `a` proved EventViewer was receiving normal keyboard events.
   - raw `caps_lock` proved Karabiner was not applying the Caps-to-super rule to that current device identity.
   - swapped modifier key codes proved the Keychron's current Bluetooth profile/layer was emitting swapped modifiers before the final correction.

5. Apply the smallest config fix and test after each step.

   First fix:
   - Add a `product_id: 640`, `vendor_id: 13364` device entry.
   - Include `is_pointing_device: true` because Karabiner reports the current Bluetooth identity as both keyboard and pointing device.

   Result:
   - Caps changed from raw `caps_lock` to the expected super chord:
     `left_command`, `left_option`, `left_shift`, `left_control`.

   Second fix:
   - Add `simple_modifications` only on the `640` Keychron device entry to correct the emitted swapped modifiers.

   Result:
   - physical left Option -> `left_option`
   - physical left Command -> `left_command`
   - physical right Command -> `right_command`
   - Caps -> super chord

6. Preserve the debugging boundary.

   Do not:
   - add or re-enable the old global/complex swap rule
   - add a vendor-only swap condition such as only `{ "vendor_id": 13364 }`
   - change the MacBook built-in keyboard settings
   - assume firmware is the first fix

   Do:
   - match the exact connected Keychron identity from Karabiner CLI
   - keep corrections under that exact device's `simple_modifications`
   - retest with EventViewer after each change
   - keep the repo config, `~/.config/karabiner/karabiner.json`, and `~/.config/karabiner/karabiner_scripts/karabiner.json` in sync

Current expected Keychron device entries:

```json
{
  "identifiers": {
    "is_keyboard": true,
    "is_pointing_device": true,
    "product_id": 560,
    "vendor_id": 13364
  },
  "ignore": false,
  "treat_as_built_in_keyboard": true
}
```

```json
{
  "identifiers": {
    "is_keyboard": true,
    "product_id": 640,
    "vendor_id": 13364,
    "is_pointing_device": true
  },
  "ignore": false,
  "treat_as_built_in_keyboard": true,
  "simple_modifications": [
    { "from": { "key_code": "left_command" }, "to": [{ "key_code": "left_option" }] },
    { "from": { "key_code": "left_option" }, "to": [{ "key_code": "left_command" }] },
    { "from": { "key_code": "right_option" }, "to": [{ "key_code": "right_command" }] },
    { "from": { "key_code": "right_command" }, "to": [{ "key_code": "right_option" }] }
  ]
}
```

Fast checks:

```bash
hidutil list | rg -i 'keychron|karabiner|internal keyboard'
hidutil property --get UserKeyMapping
defaults read -g com.apple.keyboard.modifiermapping 2>/dev/null
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --list-connected-devices
```

The Karabiner CLI may need to be run outside restricted shells/sandboxes. If `hidutil` sees the Keychron but Karabiner CLI does not, debug Karabiner service/grabber state before editing JSON.

EventViewer probe order:

1. Clear Karabiner-EventViewer.
2. Press physical left Option down/up.
3. Press physical left Command down/up.
4. Press physical right Command down/up.
5. Press physical Caps Lock down/up.
6. Press physical `a` down/up.

Expected healthy output:
- left Option -> `left_option`
- left Command -> `left_command`
- right Command -> `right_command`
- Caps Lock -> `left_command`, `left_option`, `left_shift`, `left_control`
- `a` -> `a`

Interpretation:
- If Caps appears as raw `caps_lock`, Karabiner is not applying the Caps-to-super rule to the current device identity. Check whether the connected Keychron identity has changed, especially `product_id` and `is_pointing_device`.
- If Option/Command are swapped in EventViewer before correction, the keyboard profile/layer is emitting swapped codes. Fix with a device-specific `simple_modifications` entry for that exact Keychron identity only.
- If macOS native mappings are non-empty, clear those before blaming Karabiner.
- If the device flips identity again after reset/re-pair, add the exact new identity instead of changing global rules.

Also check the physical Keychron OS switch and VIA/Keychron Launcher layer if the behavior changes again. Firmware updates are a last step; use the exact firmware for the keyboard model/layout only.

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
