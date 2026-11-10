from __future__ import annotations

import textwrap
from pathlib import Path

import pytest

from tui.modules import PLATFORM, Environment

OTHER = "linux" if PLATFORM == "mac" else "mac"


def _module(root: Path, name: str, script: str, toml: str) -> None:
    d = root / name
    d.mkdir()
    (d / "install.sh").write_text("#!/usr/bin/env bash\nset -e\n" + textwrap.dedent(script))
    (d / "module.toml").write_text(textwrap.dedent(toml))


@pytest.fixture
def home(tmp_path, monkeypatch) -> Path:
    h = tmp_path / "home"
    h.mkdir()
    monkeypatch.setenv("HOME", str(h))
    monkeypatch.setenv("XDG_STATE_HOME", str(h / ".state"))
    return h


@pytest.fixture
def root(tmp_path, home) -> Path:
    r = tmp_path / "repo"
    r.mkdir()
    (r / "lib").mkdir()
    # stand-in for lib/uninstall.sh: records the packages it was asked to remove
    (r / "lib" / "uninstall.sh").write_text('#!/usr/bin/env bash\necho "removing $*"\necho "$*" > "$HOME/uninstalled"\n')
    _module(r, "okmod", 'echo "hello from okmod"\ntouch "$HOME/.okmod"\n', f"""
        name = "okmod"
        description = "installs fine"
        platforms = ["{PLATFORM}"]
        kind = "cli"
        [detect]
        paths = ["~/.okmod"]
        [uninstall]
        brew = ["okpkg"]
        packages = ["okpkg"]
        """)
    _module(r, "failmod", 'echo "about to fail"\nexit 3\n', f"""
        name = "failmod"
        description = "always fails"
        platforms = ["{PLATFORM}"]
        kind = "cli"
        """)
    _module(r, "askmod", 'read -rp "Your name: " n\necho "hi $n"\n[[ "$n" == "sagar" ]]\n', f"""
        name = "askmod"
        description = "prompts for input"
        platforms = ["{PLATFORM}"]
        kind = "config"
        """)
    _module(r, "pwmod", 'read -rsp "[sudo] password for me: " p\necho\n[[ "$p" == "hunter2" ]] && echo "auth ok"\n', f"""
        name = "pwmod"
        description = "asks for a password"
        platforms = ["{PLATFORM}"]
        kind = "cli"
        """)
    _module(r, "cfgmod", 'echo cfg\n', f"""
        name = "cfgmod"
        description = "config only"
        platforms = ["{PLATFORM}"]
        kind = "config"
        [detect]
        paths = ["~/.cfgmod"]
        """)
    _module(r, "slowmod", 'echo start\nsleep 30\necho never\n', f"""
        name = "slowmod"
        description = "takes forever"
        platforms = ["{PLATFORM}"]
        kind = "cli"
        """)
    _module(r, "othermod", 'echo other\n', f"""
        name = "othermod"
        description = "other platform only"
        platforms = ["{OTHER}"]
        """)
    (r / "broken").mkdir()
    (r / "broken" / "module.toml").write_text("name = [")
    return r


@pytest.fixture
def probe(home):
    return lambda: Environment(path="/usr/bin:/bin")
