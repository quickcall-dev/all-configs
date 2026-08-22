# Agent Context: Karabiner Config Setup

## Repo Layout

```
~/.config/karabiner/
├── karabiner.json              # LIVE config — Karabiner-Elements reads this
└── karabiner_scripts/          # THIS REPO (git)
    ├── agents.md               # This file
    ├── app_launchers.json      # Modular: app shortcuts (Caps+G, Caps+B, etc.)
    ├── vim_arrow_keys.json     # Modular: hjkl navigation
    ├── remap_caps_lock_shift_super.json
    ├── rename_caps_lock_to_super.json
    ├── remap_escape_to_control.json
    ├── fn_to_control.json
    ├── custom_delete_mapping.json
    ├── right_shift_mouse_click.json
    ├── swap_esc_delete.json
    ├── karabiner.json            # MERGED config — copied to live config by install.sh
    ├── install.sh                # Syncs repo → live config
    └── README.md
```

## Key Rules

1. **Caps Lock = Super** (`left_control + left_shift + left_option + left_command`). All `Caps + <key>` shortcuts use that modifier combo.

2. **Two places need updating** when you change shortcuts:
   - The **modular file** in this repo (e.g. `app_launchers.json`)
   - The **live config** at `~/.config/karabiner/karabiner.json`
   - Optionally also `karabiner_scripts/karabiner.json` (the merged copy in repo)

3. **Or just use `install.sh`** — it copies `karabiner_scripts/karabiner.json` → `~/.config/karabiner/karabiner.json` and restarts Karabiner-Elements.

4. **App names vs bundle IDs** — `open -a 'App Name'` sometimes fails (e.g. WhatsApp). Use `open -b 'bundle.id'` as fallback. Get bundle ID via:
   ```bash
   mdls -name kMDItemCFBundleIdentifier /Applications/AppName.app
   ```

5. **Git workflow** — commit and push from `karabiner_scripts/` directory. Remote: `git@github.com:sagarsrc/karabiner_scripts.git`
