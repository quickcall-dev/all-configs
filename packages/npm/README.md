# @quickcall/all-configs

Run the all-configs terminal UI without installing Bun:

```bash
npx @quickcall/all-configs
```

On install (and on first run, if needed) the package downloads the matching
precompiled Bun/OpenTUI executable for your platform from the GitHub Release
and caches it. The executable contains the runtime; Bun is not required on
the user's machine.

Supported platforms:

- macOS arm64 and x64
- Linux arm64 and x64

The package also includes the module definitions and installer scripts used by the TUI.
