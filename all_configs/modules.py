"""Discover installer modules from the filesystem."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import tomllib  # Python 3.11+
except ImportError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


SKIP_DIRS = {"lib", ".git", ".worktrees", "docs", "all_configs"}


def detect_platform() -> str:
    """Return 'mac' for macOS/Darwin, 'linux' otherwise."""
    return "mac" if sys.platform == "darwin" else "linux"


def discover_modules(root_dir: Path | None = None) -> list[dict]:
    """Find modules with install.sh + module.toml matching the current platform."""
    root = root_dir or Path(__file__).resolve().parent.parent
    platform = detect_platform()
    modules: list[dict] = []

    for child in root.iterdir():
        if not child.is_dir():
            continue
        if child.name in SKIP_DIRS:
            continue
        install_script = child / "install.sh"
        manifest = child / "module.toml"
        if not install_script.exists() or not manifest.exists():
            continue

        try:
            data = tomllib.loads(manifest.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"[all-configs] skipping {manifest}: {exc}", file=sys.stderr)
            continue
        platforms = data.get("platforms", [])
        if platform not in platforms:
            continue

        modules.append(
            {
                "name": data.get("name", child.name),
                "description": data.get("description", ""),
                "platforms": platforms,
                "path": child,
            }
        )

    return modules
