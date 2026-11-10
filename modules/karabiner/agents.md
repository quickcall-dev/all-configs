# Agent Context: Karabiner Config

## Layout

This directory (`./karabiner/` in the `all-configs` dotfiles repo) is the source of truth. It is synced to the live location by `install.sh`:

```
<repo>/karabiner/                     # source of truth (this directory, git)
└── installed/synced to:
    ~/.config/karabiner/
    ├── karabiner.json                # LIVE config — Karabiner-Elements reads this
    └── karabiner_scripts/            # rsync copy of this directory (install.sh)
```

## Key rules

1. **Caps Lock = super** (`left_control + left_shift + left_option + left_command`). All `Caps + <key>` shortcuts use that modifier combo.

2. **Keep all copies in sync** when changing shortcuts:
   - The modular file here (e.g. `app_launchers.json`)
   - The merged `karabiner.json` here
   - `~/.config/karabiner/karabiner.json` (live)
   - `~/.config/karabiner/karabiner_scripts/` (rsync copy — or rerun `install.sh` to regenerate)

   Karabiner watches the live config and reloads automatically; check `~/.local/share/karabiner/log/console_user_server.log` for `core_configuration is updated`.

3. **App names vs bundle IDs** — `open -a 'App Name'` sometimes fails (e.g. WhatsApp). Use `open -b 'bundle.id'` as fallback. Get bundle ID via:
   ```bash
   mdls -name kMDItemCFBundleIdentifier /Applications/AppName.app
   ```

4. **Validate JSON** after editing:
   ```bash
   jq empty <file>
   ```

5. **Git** — commit and push from the `all-configs` repo root (`git@github.com:quickcall-dev/all-configs.git`).

6. **Never add global Command/Option swaps** — they break the MacBook built-in keyboard. Keychron corrections are device-scoped only. See `troubleshooting.md` before touching modifier rules.
