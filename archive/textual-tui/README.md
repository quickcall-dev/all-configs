# Archived: Textual TUI

The original all-configs TUI, built with [Textual](https://textual.textualize.io/).
Archived in favor of the OpenTUI rewrite (`experimental/opentui/`), but fully
intact and reusable — it is a solid, production-quality Textual app (pty job
runner, declarative module table, themes) that can serve as the base for other
TUI projects.

## Layout

- `allconfigs/` — the package slice the TUI needs: `tui/` (app, screens,
  theme, widgets) and `runner.py` (pty process + line splitting + prompt
  detection).
- `tests/` — pytest suite (unit + Textual pilot tests).
- `run-tui-tests.sh`, `pytest.ini` — test runner and config.

## Reviving

The code still imports from the live `allconfigs` package (`modules.py`,
`probe.py`) and expects the repo root on `sys.path`. To restore it:

```bash
mv archive/textual-tui/allconfigs/tui allconfigs/tui
mv archive/textual-tui/allconfigs/runner.py allconfigs/runner.py
mv archive/textual-tui/tests tests-tui   # plus pytest.ini / run-tui-tests.sh
```

Then run `uv run --no-project --python 3.12 --with 'textual==8.2.*' python3 -m allconfigs`
(or copy the pre-archive `__main__.py` and `install.sh` invocation back from
git history: `git show 8ba6118~1:install.sh`).

## As a template for other projects

The reusable pieces, in dependency order:

1. `runner.py` — framework-agnostic: pty child processes, CR-collapsing line
   splitter, sudo/password prompt detection. No Textual imports.
2. `tui/screens.py` — declarative search/multi-select/run screens.
3. `tui/theme.py`, `tui/widgets.py` — light/dark theme registration.
