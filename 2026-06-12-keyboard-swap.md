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

Added `simple_modifications` to Karabiner `~/.config/karabiner/karabiner.json`:

```json
{
  "simple_modifications": [
    { "from": { "key_code": "left_command" }, "to": [{ "key_code": "left_option" }] },
    { "from": { "key_code": "left_option"  }, "to": [{ "key_code": "left_command" }] }
  ]
}
```

This swaps the keycodes back at the Karabiner layer, effectively canceling out the hardware misreport.

## Notes

- Right modifiers unaffected
- If keyboard firmware is ever updated/flashed, remove this workaround and retest
