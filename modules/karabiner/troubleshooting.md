# Troubleshooting: Keychron K3 Pro modifier weirdness

Complete incident history reconstructed from `debug-chat.md` (~3,600 lines of debugging, 2026-06-12 → 2026-10-15). Newest first for incidents, but read the **Gold State** first.

---

## GOLD STATE (verified live 2026-10-27 — this is what works)

```bash
jq '[.profiles[].complex_modifications.rules[] | select(.description=="Correct swapped modifiers on Keychron Bluetooth Keyboard")] | length' ~/.config/karabiner/karabiner.json
# live: 1, but DISABLED ("enabled": false — Karabiner UI toggle writes this)
# repo + karabiner_scripts copies: 0 (rule fully deleted)

jq '[.profiles[].devices[] | select(.identifiers.vendor_id==13364) | {identifiers, swap: (.simple_modifications != null and (.simple_modifications|length > 0))}]' ~/.config/karabiner/karabiner.json
# → 3 entries, all swap: false

hidutil property --get UserKeyMapping
# → (null)
```

Gold state = **exactly this**:

1. **No Option/Command swap anywhere in Karabiner.** Not a complex rule (or only as a disabled shell in the live config), not device `simple_modifications`.
2. **Three Keychron device entries registered, none carrying modifier mappings:**
   - `vendor_id: 13364, product_id: 640, is_keyboard: true, is_pointing_device: true` — Bluetooth `Keychron Bluetooth Keyboard`, combined keyboard+pointing interface
   - `vendor_id: 13364, product_id: 640, is_keyboard: true, is_pointing_device: false` — same identity, keyboard-only interface shape (fallback)
   - `vendor_id: 13364, product_id: 560, is_keyboard: true, is_pointing_device: true` — USB `Keychron K3 Pro`
3. **macOS native remaps: none** (`hidutil` null, `com.apple.keyboard.modifiermapping` empty, per-device `HIDKeyboardModifierMappingPairs` empty).
4. **Keychron Launcher:** Layer 0 (Mac) bottom row `Ctrl LOpt LCmd space RCmd`. Known quirk: **Layer 2 (Windows) can get stuck active** regardless of the physical Mac/Win switch. Workaround: remap Layer 2's three bottom-row positions to `Alt`/`Win`/`Win`. Escalation: factory reset (`Fn + J + Z`, ~4s) + re-pair (`Fn + 1/2/3` held ~4s), firmware reflash last (exact K3 Pro model/layout firmware).

### The "device code" memory — both are right

| Date | What worked | Status today |
|------|-------------|--------------|
| 2026-10-01 | `product_id: 640` device entry **with `is_pointing_device: true`** | **Gold.** This is what makes Karabiner match the BT identity at all; without it Caps-as-super and all device rules silently stop applying. |
| 2026-10-01 | Device-scoped `simple_modifications` swap correction on 640 | ⚠️ Worked ~2 weeks, became the breaker on 2026-10-15. Removed. |
| 2026-10-15 | **Removing the swap correction entirely** (user toggled the complex rule off in Karabiner UI) | **Gold.** No correction = nothing to double-swap. |

**Rule #1: never re-add a Keychron Option/Command swap to Karabiner.** Every swap added across this saga eventually caused a double-swap episode.

---

## Incident 2026-10-15 (final): the Karabiner "fix" was the breaker

Full-day session. Everything tried, in order:

### Morning — diagnosis with corrections still in place

1. **Karabiner service check.** Live state: only BT `0x3434:0x280` connected, Karabiner running, `Default profile` active, BT correction loaded, macOS remaps null — still swapped. Sandboxed `karabiner_cli --list-connected-devices` had hung with `asio.system:1` and `--show-current-profile-name` also hung → briefly concluded the service was dead (logs last advanced Oct 14 13:37, launchctl print showed services absent). Restarted Karabiner via `open -a 'Karabiner-Elements'`.
2. **Correction of the false conclusion.** Re-ran the CLI outside the sandbox: service was healthy all along, saw exactly one Keychron (BT 640, keyboard+pointing), correction loaded. Lesson: sandboxed CLI failure ≠ dead service.
3. **Physical Mac/Win switch theory** — user: "no its not switching at all". Rejected.
4. **Config-rewriter theory** — searched `launchctl list`, all LaunchAgents/LaunchDaemons plists, crontab, running processes for anything touching karabiner/keychron/modifier/swap/watch. Nothing. Ruled out permanently.
5. **Caps Lock latched theory** — earlier failing trace had mouse clicks carrying `flags caps`; asked user to press Caps once and re-click. New Caps trace: correct super chord, mouse clicks with no `flags caps`. Ruled out. (Also matches the June 12 incident where latched Caps was the whole cause.)
6. **Interface-matching hypothesis.** Found via Karabiner docs: device identifiers are ANDed. Correction was on the 640 entry with `is_pointing_device: true`; if the keyboard reconnects as keyboard-only, the entry stops matching and the swap silently drops out. **Added a second, mutually exclusive 640 entry with `is_pointing_device: false` carrying the same correction** to all 3 config copies. Forced reload via `karabiner_cli --select-profile 'Default profile'` (reload confirmed 11:36:16 and 11:36:53). Announced a commit.
7. **User: "nope not working why are you committing without consulting me."** Commit stopped, nothing committed. Fallback hypothesis falsified.
8. **macOS per-device modifier prefs** — checked `.GlobalPreferences` ByHost plists and `com.apple.HIToolbox.plist` for modifier mappings tied to the Keychron. Empty.
9. **History re-read** — found the June 12 incident note (same symptom, VIA connection restored layer state). Pivoted investigation toward QMK/VIA layer state.

### Midday — the probe war

Established three-key probe: physical left Option, left Command, right Command (this board has no right Option key), down/up each, in EventViewer.

10. **Trace 1 (11:42):** physical LOpt → `left_command`, LCmd → `left_option`, RCmd → `right_option`. Swapped.
11. **Device-entry order hypothesis.** Config had a generic `{is_keyboard: true}` entry **before** the Keychron-specific entries; concluded the generic entry was being selected first so the Keychron swap never ran. **Reordered all 3 configs: 640 entries moved before the generic entry.** Reloaded.
12. **Trace 2 (11:45): unchanged.** Order hypothesis falsified. (Noted: Karabiner normalized the fallback entry's explicit `is_pointing_device: false` away on reload — harmless.)
13. **Mechanism switch.** Concluded device-level `simple_modifications` was not being applied at all. Replaced it with a **device-scoped complex rule** "Correct swapped modifiers on Keychron Bluetooth Keyboard": 4 manipulators (`left_command→left_option`, `left_option→left_command`, `right_option→right_command`, `right_command→right_option`), each with `device_if` on `vendor_id 13364, product_id 640` and `modifiers: optional any`. Same mechanism as the proven-working Caps rule. Removed all device `simple_modifications` so no double-swap was possible. Reloaded.
14. **Trace 3 (11:48): unchanged.** "This rules out both of my mapping fixes. Stopping configuration edits."
15. **Read-only verification.** `karabiner_cli --list-connected-devices` + rule jq + log tails: live identity and rule exact match, yet zero effect. Concluded the keyboard itself was emitting Windows-order codes and the repair point was the saved VIA keymap.

### Afternoon — Keychron Launcher investigation

16. Guided user to `launcher.keychron.com` (USB cable mode). Keychron docs: layers 0/1 = Mac, 2/3 = Windows.
17. **Discovery 1:** user had been editing **Layer 2 (Windows)**. Layer 0 (Mac) bottom row was already correct: `Ctrl LOpt LCmd space RCmd`.
18. Guided Layer 0 edits anyway: LOpt→`Alt`, LCmd→`Win`, RCmd→`Win` (Keychron calls macOS Command "Win"/"GUI" in its UI). User hit a snag choosing keys with the keyboard mid-remap ("not able to use win now") → advised using the mouse in the picker.
19. **Discovery 2 (screenshot):** Layer 0 selected in the UI (gray pill), its layout correct, **but Layer 2 shown green = the keyboard's active layer**. Physical Mac/Win switch not changing the active firmware layer.
20. Advised: move physical switch to Mac, check Layer 0 goes green. User: **"layer 2 is being highlighted no matter where i switch"** → QMK layer selector stuck on Layer 2. Advised editing Layer 2's three positions to Mac order (`LAlt`/`LWin`/`LWin`) as workaround; firmware reflash as the real fix for the stuck selector.

### The actual fix

21. **User: "I removed the rule which was saying correct keys for swapped Bluetooth or something in complex modification, and now it's working for some reason."**

The complex correction rule added in step 13 was the active breaker. Removing it fixed everything immediately. No layer edits were needed; Launcher work was abandoned mid-way.

### Root cause of the whole day

EventViewer was misread as proof of final macOS output. It shows Karabiner-processed events — the "from" column (`Karabiner DriverKit VirtualHIDKeyboard`) is the virtual device, and the trace interpretation that "the keyboard is emitting Windows-order codes" was the swap rule's own output in several of the earlier episodes. The Oct 1 fix (correction for 640) was correct *while the keyboard was in a bad state*, but the keyboard state kept changing underneath (resets, re-pairs, Launcher connections refreshing it), so a persistent correction alternated between correcting and double-swapping. That interplay is the entire source of the "random every few minutes" behavior.

### Config drift found and fixed 2026-10-27

The user's UI toggle wrote `enabled: false` to the **live** config only. Repo and `karabiner_scripts/` copies still had the rule with **no `enabled` field — which defaults to enabled** in Karabiner. Any `install.sh` re-sync would have re-broken the keyboard. Rule fully deleted from both copies on 2026-10-27; verified all three copies now agree (rule gone/disabled, 3 device entries, no swaps, macOS remaps null).

---

## Incident 2026-10-01 (afternoon): identity flip broke Caps-as-super, then modifiers

### Morning context

Factory reset (`Fn + J + Z`) temporarily fixed the swap, then it broke again ("now its fucked again"). Live check: Karabiner clean (all corrections off since Sep 27, hidutil null, config mtime Sep 27 10:52:40) — yet swapped after wake/reconnect at 12:33:05.

### The identity discovery

`hidutil list` showed the keyboard as **`0x3434 0x280 "Keychron Bluetooth Keyboard"`** — new vendor/product pair. Historically it was `0x3434 0x230 "Keychron K3 Pro"` (decimal `13364/560`). The reset/re-pair had re-enumerated it as product **640** — an identity the config didn't know. Advised re-pairing in Mac mode as the root fix; added 640 as a known device entry as the workaround.

### Caps-as-super failure

"NOW CAPS IS NOT BEING USED AS SUPER." Full investigation:

1. Verified Caps rule present (rule index 0 — first shot at the event), devices list, profile.
2. Added a `product_id: 640` device entry (is_keyboard only) to live + scripts + repo.
3. `karabiner_cli` probes: sandboxed runs hung (`asio.system:1`, `--show-current-profile-name` hung) → looked like service trouble; outside sandbox it reported the 640 as **both keyboard and pointing device**.
4. macOS per-device prefs (`ioreg`, `.GlobalPreferences`) — no Keychron modifier mapping.
5. First full probe trace (14:46): physical LOpt → `left_command`, LCmd → `left_option`, RCmd → `right_option`, **Caps → raw `caps_lock`**, `a` → `a`. Mouse clicks carried `flags caps` (latched Caps at that moment — separate red herring). Two failures at once: Karabiner not applying device rules to this identity, and apparent swapped modifiers.
6. **Root cause of Caps:** the 640 entry lacked `is_pointing_device: true`; Karabiner ANDs identifiers, so the entry never matched the combined keyboard+pointing interface. Fixed all 3 copies with a ruby script. Reload confirmed 14:48:20.
7. Trace 2 (14:48:52): **Caps → super chord restored** (LCmd+LOpt+LShift+LCtrl down/up). Modifiers still showing swapped.
8. Added device-scoped `simple_modifications` swap correction on 640 (left/right Option↔Command). Reload 14:49:40.
9. Trace 3 (14:59): all correct — LOpt→`left_option`, LCmd→`left_command`, RCmd→`right_command`, Caps→super chord, `a`→`a`. "now its working fuckin hell."

### Docs + commit

- User asked for a doc so it never happens again → replaced the stale July troubleshooting section in repo `README.md` with the root-cause notes and probe protocol.
- Commit `e604489` → amended to `ad72f55` ("Document Keychron Karabiner device fix"), author/committer `Sagar Sarkale <sagarsarkale.work@gmail.com>`. Push initially blocked by the safety layer.
- Helper script `keychron-modifier-swap.sh` deliberately **not** committed at the time — it hard-coded only product 560.

---

## Incident between: two transports at once

"It happened again" — `hidutil list` showed **both** `0x230 Keychron K3 Pro` (USB) and `0x280 Keychron Bluetooth Keyboard` (BT) simultaneously; `karabiner_cli --list-connected-devices` confirmed both in Karabiner's view. Correction existed only on 640. Deliberately did **not** add a swap to 560 (that exact move had caused a double-swap on Sep 25). Asked for a trace including the "from" device column, and gave the fastest physical test: unplug USB / switch to BT-only. Confirmed the uncorrected transport was carrying keystrokes. This is why gold state keeps a 560 entry registered.

---

## Incident 2026-09-25: "swap resets every few minutes"

The opening saga. Full session log:

### Diagnosis (first turns)

1. User: Karabiner keeps swapping left Option/Command "every few minutes."
2. Inspected live config + automatic backups. Found complex rule **"Swap left and right Option/Command on Keychron"** plus per-device `simple_modifications` — overlapping mapping surfaces.
3. **Key evidence:** automatic backup `karabiner_20260925.json` (12:46:07) had the rule active; live config changed at 13:07:43 contained `"enabled": false` on exactly that rule. Diff = that single line.
4. Karabiner logs showed reloads at 12:46:07, 13:00:48, 13:07:43 — config file being rewritten, then reloaded.
5. **Writer hunt:** `ps aux` + `launchctl list` → Karabiner, Raycast, Logitech Options+ running; no goku/skhd/yabai/hidutil keymap daemons. Searched Raycast config/support, LaunchAgents, Preferences plists, home-directory scripts referencing karabiner/left_option/left_command — nothing. Broad home search abandoned as too slow.
6. Backup history clean across all automatic backups → disabled state was transient, written after backups, not baked into any template.
7. Concluded: Karabiner's own UI/API path was writing the toggle; recommended moving the swap out of complex rules into device `simple_modifications` where no enable/disable flag exists.

### Watcher (intermittency trap)

8. User: "this keeps happening intermittently." Built **`watch-karabiner-swap.sh`** — 1s poll of config hash + rule state, logs only on change, captures reload lines and process context. First start raced the chmod (permission denied), restarted detached as PID 77522, logging to `outputs/karabiner-swap-watch.log`. Started from broken state (`rule_state: false`).
9. Later: user reported a change; watcher had **died** without catching anything; config mtime unchanged since 13:07:43; Karabiner log showed no new reload (only an update check at 13:40:36). Conclusion: this occurrence was **device/layer/reconnect state**, not a config rewrite. Two distinct failure modes established: (a) config file rewritten with the rule disabled, (b) behavior changes with no config change at all.

### The flip-flop fix attempts

10. **Attempt A (user-approved):** jq transform on live + `karabiner_scripts/`: removed the complex rule, added the four-way Option/Cmd swap as device `simple_modifications` on `13364/560`. Backed up both files with timestamps. Reload 15:23:27. Verified structure.
11. **Propagated to repo** (`all-configs/karabiner/karabiner.json`). jq reformatted the whole file → restored from backup, applied minimal perl patch (remove rule block, insert simple_modifications). Clean diff.
12. **User: "keychron is swapped btw wtf"** — the device-level swap double-swapped: the keyboard was *already* presenting the modifier order the user wanted at that moment. Removed `simple_modifications` from all 3 files. Reload 15:26:47. Restored repo formatting again (jq churn), leaving only the complex-rule removal.
13. **User: "bc thats swapped again"** — with Karabiner completely clean (no complex rule, no device swap, hidutil null), it flipped back. Conclusion: the keyboard firmware/layer state was changing underneath. Re-added the device swap to all 3 files to correct the current bad state. Reload 15:51:24.
14. Built **`keychron-modifier-swap.sh`** (on/off/status helper) and committed it into the repo so the mapping could be flipped in one command per state change. Repo diff cleaned once more via backup-restore + perl patch (jq kept reformatting).

### Tooling + interpretation lessons

15. "Is there a CLI way?" — this Mac **lacks `hidutil eventmonitor`**. Documented CLI checks (helper status, hidutil property, modifiermapping, hidutil list). Keychron visible as `0x3434/0x230` matching `13364/560`.
16. "Any stable GitHub repo?" — KeyCastr (GUI), Objective-See **sniffMK** (CLI-ish, root, old), pqrs **osx-event-observer-examples** (code, not tool). EventViewer stays the probe.
17. "Why are we doing this?" — articulated the three-layer model: Keychron firmware/layer, macOS native modifier mapping, Karabiner config. Goal: identify which layer owns the current swap.
18. **EventViewer screenshot lesson:** user pasted a trace showing `from Karabiner DriverKit VirtualHIDKeyboard 1.8.0` → that is Karabiner's **output**, not raw Keychron input. With the correction on, EventViewer shows corrected events; it cannot prove what the keyboard emits. Protocol established: disable correction → press physical Option/Command → read trace → decide.
19. **"Mac keyboard fine, Keychron swapped" episode:** with the Keychron-only complex rule confirmed as the cause of that particular swap, turned the correction **off in all 3 files**. Reload 10:52:40 (Sep 27). Both keyboards normal.
20. **"But what is causing it?"** — root cause as understood then: a Keychron-only swap rule existing in config + intermittent state changes + the stale `enabled: false` churn. All corrections off, macOS clean.
21. **"check it just happened" (Oct 1 morning):** all configs off, hidutil null, Keychron connected normally, config unchanged since Sep 27 10:52:40, only event = wake/reconnect 12:33:05 loading config. With Karabiner fully clean and still broken → the cause was below Karabiner. Led directly into the Oct 1 identity-flip incident.

**Postscript:** the external writer of the Sep 25 `enabled: false` flips was never found. With the Oct 15 root cause known, the flips tracked the keyboard's own state changes interacting with the persistent swap rule — not a daemon.

---

## Incident 2026-06-12: Caps Lock was on

Left Option appeared to send `left_command`, `Cmd+C` typed `ç`. **Caps Lock was on** — the apparent swap was Caps Lock state + keyboard layout. A factory reset (`Fn + J + Z`) was performed unnecessarily before noticing. Lessons: check Caps Lock first (EventViewer: latched Caps shows as `flags caps` on mouse events); K3 Pro is QMK/VIA; physical Mac/PC switch should be on Mac. This incident recurred as a red herring on 2026-10-15 (trace had `flags caps` on mouse clicks).

---

## Hard-won cross-cutting lessons

1. **EventViewer shows post-Karabiner events.** The "from" column names the virtual HID device. Never conclude "firmware emits swapped codes" from an EventViewer trace while any Karabiner rule is active. This single misreading cost most of Oct 15.
2. **Sandboxed `karabiner_cli` lies.** Inside restricted shells it can hang (`asio.system:1`) or falsely show services absent. Run it with normal permissions before concluding Karabiner is dead.
3. **Karabiner ANDs device identifiers.** Both interface shapes of the BT identity exist (keyboard+pointing vs keyboard-only) → the two 640 entries in gold state.
4. **A complex rule with no `enabled` field defaults to enabled.** Karabiner UI toggles write `enabled: false` to the live config only — repo copies need manual deletion, not just UI toggles, or `install.sh` reintroduces the rule.
5. **Three copies must stay in sync:** repo `karabiner/karabiner.json`, live `~/.config/karabiner/karabiner.json`, rsync copy `~/.config/karabiner/karabiner_scripts/karabiner.json`. After edits: `jq empty` + confirm `core_configuration is updated` in `~/.local/share/karabiner/log/console_user_server.log`.
6. **The keyboard enumerates under two identities:** USB `0x3434/0x230` (product 560, `Keychron K3 Pro`) and BT `0x3434/0x280` (product 640, `Keychron Bluetooth Keyboard`). Both can be connected simultaneously; only one carries keystrokes. After any reset/re-pair, re-check identity.
7. **Keychron Launcher layer quirk:** Layer 2 (Windows) can be stuck active regardless of the physical switch. Check which layer is green before editing anything.
8. **Don't commit config changes while the fix is unproven** (Oct 15 commit attempt was rightly stopped).

---

## Debug playbook

### 0. Check Caps Lock first

EventViewer → click mouse. `flags caps` on clicks = Caps latched → press Caps once, retest. (Two incidents were/started as this.)

### 1. Verify gold state (below). If gold holds and keys are wrong → keyboard-side, step 5. Do NOT add Karabiner swaps.

```bash
jq '[.profiles[].complex_modifications.rules[] | select((.manipulators//[])|tostring|test("left_option|left_command|right_option|right_command")) | {description, enabled}]' ~/.config/karabiner/karabiner.json
jq '[.profiles[].devices[] | select(.identifiers.vendor_id==13364) | {identifiers, swap: (.simple_modifications != null and (.simple_modifications|length > 0))}]' ~/.config/karabiner/karabiner.json
hidutil property --get UserKeyMapping
defaults read -g com.apple.keyboard.modifiermapping 2>/dev/null
```

### 2. Identity + transport

```bash
hidutil list | rg -i 'keychron|karabiner|internal keyboard'
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --list-connected-devices   # outside sandboxed shells
```

Expected BT form: `vendor_id 13364, product_id 640, is_keyboard: true, is_pointing_device: true`. If both 560 and 640 appear, only one carries keystrokes.

### 3. Profile + reload

```bash
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name
tail -n 20 ~/.local/share/karabiner/log/console_user_server.log
```

Healthy: `Default profile`, `core_configuration is updated` after edits, no parse errors.

### 4. EventViewer probe

Clear → press down/up one at a time: physical left Option, left Command, right Command, Caps, `a`. Expected healthy: `left_option`, `left_command`, `right_command`, Caps = super chord, `a`. Interpret as post-Karabiner (lesson 1).

### 5. Keyboard-side fixes — the only class of fix that ever held

1. Caps Lock off (step 0).
2. Physical OS switch firmly to Mac; power-cycle BT.
3. Keychron Launcher (`launcher.keychron.com`, USB cable mode): check which layer is green. Layer 0 = Mac base (`Ctrl LOpt LCmd space RCmd`). If Layer 2 stuck active: remap its three positions to `Alt`/`Win`/`Win` as workaround.
4. Factory reset `Fn + J + Z` (~4s), re-pair `Fn + 1/2/3` hold ~4s.
5. Delete the BT pairing in macOS System Settings → Bluetooth, re-pair fresh.
6. Firmware reflash **last** — exact K3 Pro model/layout firmware only. This is the escalation for the stuck Layer 2 selector.

### Do / Don't

**Do:** keep all three config copies in sync; delete (not disable) swap rules in repo copies; validate JSON; confirm reload; re-check device identity after every reset/re-pair.

**Don't:** re-add any Keychron Option/Command swap to Karabiner; add global Command/Option swaps; commit unproven fixes; trust sandboxed CLI failures; read EventViewer as raw firmware output; edit Launcher layers before checking which layer is actually active.
