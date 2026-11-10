"""Module discovery and install-state detection.

A module is a directory with an ``install.sh`` and a ``module.toml``::

    name = "tmux"
    description = "tmux config, TPM, vim nav, clipboard"
    platforms = ["mac", "linux"]
    kind = "config"                 # app | cli | config

    [detect]                        # every key optional
    commands = ["tmux"]             # any on PATH  -> tool present
    brew = ["tmux"]                 # any brew formula/cask (macOS)
    apps = ["Ghostty"]              # any /Applications/<name>.app (macOS)
    paths = ["~/.tmux.conf"]        # all must exist -> config applied
    paths_mac = [...]               # extra paths, macOS only
    paths_linux = [...]             # extra paths, Linux only

    [uninstall]                     # omit = uninstall disabled
    brew = ["tmux"]                 # macOS: Homebrew formula/cask names
    packages = ["tmux"]             # Linux: apt/dnf/pacman package names

Status combines the two halves: tool present and config applied.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tomllib
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

if sys.platform == "darwin":
    PLATFORM = "mac"
elif sys.platform.startswith("linux"):
    PLATFORM = "linux"
else:
    PLATFORM = "unsupported"

KINDS = ("app", "cli", "config")

# Installers drop binaries here; the parent shell may not have them on PATH yet.
EXTRA_BIN_DIRS = (
    "~/.local/bin",
    "~/.bun/bin",
    "~/.cargo/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/home/linuxbrew/.linuxbrew/bin",
)

APP_DIRS = (Path("/Applications"), Path("~/Applications").expanduser())


class Status(str, Enum):
    CHECKING = "checking"
    INSTALLED = "installed"
    PARTIAL = "partial"
    MISSING = "missing"
    UNKNOWN = "unknown"


class ModuleError(ValueError):
    """A module.toml that cannot be used."""


@dataclass
class Module:
    name: str
    description: str
    platforms: tuple[str, ...]
    kind: str
    path: Path
    commands: tuple[str, ...] = ()
    brew: tuple[str, ...] = ()
    apps: tuple[str, ...] = ()
    paths: tuple[str, ...] = ()
    uninstall_packages: tuple[str, ...] = ()
    status: Status = Status.CHECKING
    last_run_failed: bool = field(default=False, compare=False)

    @property
    def install_script(self) -> Path:
        return self.path / "install.sh"

    @property
    def can_uninstall(self) -> bool:
        # Config modules only configure a tool; removing them must never
        # remove the tool itself, so uninstall is disabled for them.
        return self.kind != "config" and bool(self.uninstall_packages)


def _str_list(table: dict, key: str, where: str) -> tuple[str, ...]:
    value = table.get(key, [])
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        raise ModuleError(f"{where}: '{key}' must be a list of strings")
    return tuple(value)


def parse_module(toml_path: Path, platform: str = PLATFORM) -> Module | None:
    """Parse one module.toml. Returns None when the module targets another platform."""
    where = str(toml_path)
    try:
        data = tomllib.loads(toml_path.read_text())
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise ModuleError(f"{where}: {exc}") from exc

    directory = toml_path.parent
    name = data.get("name", directory.name)
    if name != directory.name:
        raise ModuleError(f"{where}: name '{name}' must match directory '{directory.name}'")
    platforms = _str_list(data, "platforms", where) or ("mac", "linux")
    if platform not in platforms:
        return None
    kind = data.get("kind", "config")
    if kind not in KINDS:
        raise ModuleError(f"{where}: kind must be one of {', '.join(KINDS)}")
    if not (directory / "install.sh").is_file():
        raise ModuleError(f"{where}: missing install.sh")

    detect = data.get("detect", {})
    uninstall = data.get("uninstall", {})
    paths = _str_list(detect, "paths", where) + _str_list(detect, f"paths_{platform}", where)
    packages = _str_list(uninstall, "brew" if platform == "mac" else "packages", where)

    return Module(
        name=name,
        description=str(data.get("description", "")),
        platforms=platforms,
        kind=kind,
        path=directory,
        commands=_str_list(detect, "commands", where),
        brew=_str_list(detect, "brew", where),
        apps=_str_list(detect, "apps", where),
        paths=paths,
        uninstall_packages=packages,
    )


def load_modules(root: Path, platform: str = PLATFORM) -> tuple[list[Module], list[str]]:
    """Discover modules under ``root``. Bad module.toml files are reported, not fatal."""
    modules: list[Module] = []
    errors: list[str] = []
    for toml_path in sorted(root.glob("*/module.toml")):
        try:
            module = parse_module(toml_path, platform)
        except ModuleError as exc:
            errors.append(str(exc))
            continue
        if module is not None:
            modules.append(module)
    return modules, errors


@dataclass(frozen=True)
class Environment:
    """Facts about the machine shared by every module's detection."""

    path: str
    brew_packages: frozenset[str] = frozenset()
    platform: str = PLATFORM


def search_path() -> str:
    dirs = os.environ.get("PATH", "").split(os.pathsep)
    dirs += [os.path.expanduser(d) for d in EXTRA_BIN_DIRS]
    return os.pathsep.join(dict.fromkeys(d for d in dirs if d))


def probe_environment() -> Environment:
    """Collect PATH and Homebrew package lists (two `brew list` calls, run in parallel)."""
    path = search_path()
    brew = shutil.which("brew", path=path)
    if PLATFORM != "mac" or not brew:
        return Environment(path=path)
    procs = [
        subprocess.Popen(
            [brew, "list", flag, "-1"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        for flag in ("--formula", "--cask")
    ]
    names: set[str] = set()
    for proc in procs:
        try:
            out, _ = proc.communicate(timeout=60)
        except subprocess.TimeoutExpired:
            proc.kill()
            continue
        if proc.returncode == 0:
            names.update(line.strip() for line in out.splitlines() if line.strip())
    return Environment(path=path, brew_packages=frozenset(names))


def detect(module: Module, env: Environment) -> Status:
    tool_checks: list[bool] = []
    if module.commands:
        tool_checks.append(any(shutil.which(c, path=env.path) is not None for c in module.commands))
    if module.brew and env.platform == "mac" and env.brew_packages:
        tool_checks.append(any(b in env.brew_packages for b in module.brew))
    if module.apps and env.platform == "mac":
        tool_checks.append(any((d / f"{a}.app").is_dir() for d in APP_DIRS for a in module.apps))

    results: list[bool] = []
    if tool_checks:
        results.append(any(tool_checks))
    if module.paths:
        results.append(all(Path(p).expanduser().exists() for p in module.paths))

    if not results:
        return Status.UNKNOWN
    if all(results):
        return Status.INSTALLED
    if any(results):
        return Status.PARTIAL
    return Status.MISSING
