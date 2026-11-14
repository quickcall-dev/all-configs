"""NDJSON probe for external TUIs (e.g. the OpenTUI experiment).

Reuses the same discovery and detection logic as the Textual TUI and prints
one JSON object per line so a parent process can stream results:

    {"type": "env", "platform": "mac", "root": "/path/to/repo"}
    {"type": "error", "message": "modules/foo/module.toml: ..."}
    {"type": "module", "module": {"name": "tmux", "status": "installed", ...}}

Usage::

    python3 -m allconfigs.probe [repo-root]   # run from the repo root
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from allconfigs.modules import detect, load_modules, probe_environment


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]

    def emit(payload: dict) -> None:
        try:
            print(json.dumps(payload), flush=True)
        except BrokenPipeError:
            # The consumer went away; nothing useful left to do.
            raise SystemExit(0)

    env = probe_environment()
    emit({"type": "env", "platform": env.platform, "root": str(root)})

    modules, errors = load_modules(root, env.platform)
    for error in errors:
        emit({"type": "error", "message": error})
    for module in modules:
        module.status = detect(module, env)
        emit(
            {
                "type": "module",
                "module": {
                    "name": module.name,
                    "description": module.description,
                    "kind": module.kind,
                    "platforms": list(module.platforms),
                    "status": module.status.value,
                    "can_uninstall": module.can_uninstall,
                    "uninstall_packages": list(module.uninstall_packages),
                },
            }
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
