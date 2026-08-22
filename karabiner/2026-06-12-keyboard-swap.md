# Keyboard: Modifier Keys Appear Swapped — Check Caps Lock First

**Date:** 2026-06-12
**Keyboard:** Keychron K3 Pro (QMK firmware, Bluetooth)
**Ghostty:** 1.3.1

## Symptom

Left Option key appeared to send `left_command` and Left Command key appeared to send `left_option`. `Cmd+C` typed `ç` instead of copying.

## Root Cause

**Caps Lock was on.** The apparent Cmd/Option swap was caused by Caps Lock state interacting with the active keyboard layout. Always check Caps Lock before assuming firmware or remap issues.

## Fix

Press **Caps Lock** to turn it off. Verify the LED/state indicator.

## What confused the diagnosis

- The issue looked like a hardware-level key swap, so we suspected the QMK firmware layer.
- A factory reset (`Fn + J + Z` held for 4 seconds) was performed, but the real cause was simply Caps Lock being active.
- macOS System Settings → Modifier Keys, `hidutil`, and Karabiner changes were unnecessary because there was no actual firmware remap.

## Notes

- Check Caps Lock first on any "swapped key" or "wrong character" issue.
- K3 Pro uses QMK with VIA support; firmware reset is only needed if the keymap has actually been changed at usevia.app.
- Physical Mac/PC switch on the side should be set to Mac for macOS.
- Right modifiers were unaffected throughout.
- If a firmware update is ever performed, retest the layout afterward.
