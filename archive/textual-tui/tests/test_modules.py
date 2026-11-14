from __future__ import annotations

from allconfigs.modules import Environment, Status, detect, load_modules, parse_module
from allconfigs.runner import LineSplitter, looks_like_password, looks_like_prompt, strip_ansi


def test_load_filters_platform_and_reports_errors(root):
    modules, errors = load_modules(root)
    names = [m.name for m in modules]
    assert names == ["askmod", "cfgmod", "failmod", "okmod", "pwmod", "slowmod"]
    assert len(errors) == 1 and "broken" in errors[0]


def test_config_modules_cannot_uninstall(root):
    modules = {m.name: m for m in load_modules(root)[0]}
    assert modules["okmod"].can_uninstall
    assert modules["okmod"].uninstall_packages == ("okpkg",)
    assert not modules["cfgmod"].can_uninstall
    assert not modules["failmod"].can_uninstall  # no [uninstall] table


def test_detect_states(root, home):
    m = parse_module(root / "modules" / "okmod" / "module.toml")
    env = Environment(path="/usr/bin:/bin")
    assert detect(m, env) is Status.MISSING
    (home / ".okmod").touch()
    assert detect(m, env) is Status.INSTALLED
    m.commands = ("definitely-not-a-command",)
    assert detect(m, env) is Status.PARTIAL
    bare = parse_module(root / "modules" / "failmod" / "module.toml")
    assert detect(bare, env) is Status.UNKNOWN


def test_line_splitter_handles_crlf_and_progress():
    s = LineSplitter()
    assert s.feed(b"one\r\ntw") == ["one"]
    assert s.partial == "tw"
    assert s.feed(b"o\r\n10%\r50%\r100%\r\nPassword:") == ["two", "100%"]
    assert s.partial == "Password:"
    assert s.flush() == ["Password:"]


def test_split_utf8_across_chunks():
    s = LineSplitter()
    data = "✓ ok\n".encode()
    assert s.feed(data[:1]) == []
    assert s.feed(data[1:]) == ["✓ ok"]


def test_prompt_heuristics():
    assert looks_like_password("[sudo] password for sagar: ")
    assert looks_like_password("Password:")
    assert not looks_like_password("Your name: ")
    assert looks_like_prompt("Your name: ")
    assert looks_like_prompt("Continue? (y/N) ")
    assert not looks_like_prompt("==> Downloading https://example.com/x.tar.gz")
    assert strip_ansi("\x1b[1;32m✓\x1b[0m done") == "✓ done"
