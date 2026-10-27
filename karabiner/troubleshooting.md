# Troubleshooting: Keychron K3 Pro modifier weirdness

Two incidents on record, newest first. Both looked like a Karabiner misconfiguration; both had other causes. Work through this playbook before editing config.

---

## Incident 2026-10-01: Keychron changed Bluetooth identity after reset/re-pair

### Symptom

- Caps Lock stopped behaving like super.
- Physical left Option emitted `left_command`.
- Physical left Command emitted `left_option`.
- Physical right Command emitted `right_option`.
- MacBook built-in keyboard was unaffected.

### Root cause

After a Keychron reset/re-pair, macOS/Karabiner no longer saw the keyboard as the old K3 Pro identity:

- old: `vendor_id: 13364`, `product_id: 560`, product `Keychron K3 Pro`
- new: `vendor_id: 13364`, `product_id: 640`, product `Keychron Bluetooth Keyboard`

The new `640` identity was observed as both `is_keyboard: true` and `is_pointing_device: true`. Karabiner ANDs every identifier in a device entry, so a rule matching only one interface shape stops matching when the keyboard reconnects in the other shape (e.g. keyboard-only, `is_pointing_device: false`). The Caps-to-super rule and the modifier correction then silently disappear even though the profile and physical selector have not changed.

EventViewer also proved the Keychron's Bluetooth profile itself was emitting swapped modifier codes — so the fix is a device-scoped `simple_modifications` correction on the exact `vendor_id: 13364, product_id: 640` identity only. Never a global swap: that breaks the built-in keyboard.

Durable config: two mutually exclusive `640` entries, one with `is_pointing_device: true`, one with `is_pointing_device: false`, each carrying the same four modifier corrections. Mutually exclusive → a key can never be swapped twice.

### Expected device entries

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

(Plus the mirror `640` entry with `is_pointing_device: false` and the same `simple_modifications`.)

### Do / Don't

Do:
- Match the exact connected Keychron identity from Karabiner CLI.
- Keep corrections under that exact device's `simple_modifications`.
- Retest with EventViewer after each change.
- Keep repo config, `~/.config/karabiner/karabiner.json`, and `~/.config/karabiner/karabiner_scripts/karabiner.json` in sync.

Don't:
- Add or re-enable a global/complex Command/Option swap rule.
- Add a vendor-only condition such as `{ "vendor_id": 13364 }`.
- Change the MacBook built-in keyboard settings.
- Assume firmware is the first fix.

---

## Incident 2026-06-12: Caps Lock was on

### Symptom

Left Option appeared to send `left_command` and vice versa. `Cmd+C` typed `ç`.

### Root cause

**Caps Lock was on.** Caps Lock state interacting with the keyboard layout produced the apparent swap. A factory reset (`Fn + J + Z` held 4s) was performed unnecessarily.

### Fix

Press Caps Lock to turn it off. Check the LED/state indicator.

### Lessons

- **Check Caps Lock first** on any "swapped key" or "wrong character" issue.
- K3 Pro uses QMK with VIA support; firmware reset is only needed if the keymap was actually changed at usevia.app.
- Physical Mac/PC switch should be set to Mac for macOS.
- Right modifiers were unaffected throughout.

---

## Debug playbook

### 0. Check Caps Lock

See incident 2026-06-12. Rule this out before anything else.

### 1. Rule out macOS native mappings and stale Karabiner rules

```bash
hidutil property --get UserKeyMapping
defaults read -g com.apple.keyboard.modifiermapping 2>/dev/null
jq '.profiles[0].complex_modifications.rules[] | select((.description|ascii_downcase|contains("swap")) or ((.manipulators // []) | tostring | test("left_option|left_command|right_option|right_command")))' ~/.config/karabiner/karabiner.json
```

Healthy: `UserKeyMapping` is `(null)`, no modifier mapping, no enabled complex swap rule.

### 2. Compare what macOS sees with what Karabiner sees

```bash
hidutil list | rg -i 'keychron|karabiner|internal keyboard'
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --list-connected-devices
```

Key question: does the connected keyboard identity (especially `product_id`, `is_pointing_device`) match a device entry in the config? Karabiner ANDs identifiers — both Bluetooth interface shapes (`is_pointing_device: true` and `false`) need their own entry.

### 3. Verify the active profile and the Caps rule

```bash
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name
jq '.profiles[] | {name, selected, devices: [.devices[] | select(.identifiers.vendor_id==13364)], caps_rule: [.complex_modifications.rules[] | select(.description=="Remap caps_lock to super") | .description]}' ~/.config/karabiner/karabiner.json
tail -n 20 ~/.local/share/karabiner/log/console_user_server.log
```

Healthy: correct profile selected, `Remap caps_lock to super` present, `core_configuration is updated` after edits.

### 4. EventViewer is the source of truth

Probe order (after Karabiner processing):

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
- Caps Lock -> `left_command`, `left_option`, `left_shift`, `left_control` (super chord)
- `a` -> `a`

Interpretation:
- Caps appears as raw `caps_lock` → the Caps-to-super rule is not matching the current device identity. Check `product_id` / `is_pointing_device`.
- Option/Command swapped in EventViewer → the keyboard's layer is emitting swapped codes. Fix with device-scoped `simple_modifications` for that exact identity only.
- macOS native mappings non-empty → clear those before blaming Karabiner.
- Device flips identity after reset/re-pair → add the exact new identity; don't change global rules.

### 5. Last resorts

- Check the physical Keychron OS switch (must be Mac for macOS).
- Check VIA/Keychron Launcher layer state; connecting `https://usevia.app` has refreshed stuck layer state before.
- Firmware update last; use the exact firmware for the model/layout, then retest.

### Notes

- The Karabiner CLI may need to run outside restricted shells/sandboxes. If `hidutil` sees the Keychron but Karabiner CLI does not, debug Karabiner service/grabber state before editing JSON.
