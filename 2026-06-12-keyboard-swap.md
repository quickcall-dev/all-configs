# Keyboard: Left Cmd/Option Swapped

**Date:** 2026-06-12
**Keyboard:** Physical keyboard in Mac mode
**Ghostty:** 1.3.1

## Symptom

Left Option key sending `left_command` keycode at hardware level. Left Command key sending `left_option`. Effectively swapped.

## Investigation

- macOS System Settings → Modifier Keys: set correctly, no swap configured
- `hidutil property --get UserKeyMapping`: null (no system-level remap)
- Karabiner complex_modifications: caps_lock only, no simple modifications
- Ghostty config: no modifier key settings
- Keyboard dip switch / mode switch: set to Mac

## Root Cause

Physical keyboard firmware or hardware misreporting keycodes. Option key sends command scancode, vice versa. Likely a keyboard firmware glitch or manufacturing defect on the left modifier row.

## Fix

Added `complex_modifications` rule to Karabiner `~/.config/karabiner/karabiner.json`. Simple_modifications format was wrong (`to` needs bare object, not array). Complex_modifications uses array format for `to` which works correctly.

Restart Karabiner required after config change.

```json
{
  "description": "Fix swapped left cmd/option",
  "manipulators": [
    {
      "type": "basic",
      "from": { "key_code": "left_command" },
      "to": [{ "key_code": "left_option" }]
    },
    {
      "type": "basic",
      "from": { "key_code": "left_option" },
      "to": [{ "key_code": "left_command" }]
    }
  ]
}
```

## Notes

- Right modifiers unaffected
- If keyboard firmware is ever updated/flashed, remove this workaround and retest
