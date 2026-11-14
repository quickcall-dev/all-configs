# all-configs TUI — OpenTUI experiment

A reimplementation of the all-configs TUI ([`allconfigs/tui/`](../../allconfigs/tui/), Textual) using [OpenTUI](https://opentui.com) with the React bindings. The Textual TUI is untouched; this lives side-by-side as an experiment.

## Run

```bash
cd experimental/opentui
bun install     # first time only
bun run start   # or: bun run src/index.tsx
```

## Test

```bash
bun test        # unit + end-to-end tests (the e2e ones run real discovery
                # and a real idempotent install of the `aliases` module)
bunx tsc -p tsconfig.json --noEmit
```

## Architecture

```
src/
  index.tsx              entry: createCliRenderer + createRoot, TTY guard
  App.tsx                state machine (main / run), discovery lifecycle, plans
  bridge.ts              Python bridge + job runner
    discover()           spawns `uv run ... python3 -m allconfigs.probe`,
                         streams NDJSON (same discovery/detection as Textual)
    runJob()             runs installers under `script(1)` so they get a real
                         pty (colors, sudo/read prompts). A reply pty allocated
                         via bun:ffi (posix_openpt) feeds typed answers back —
                         Bun's own pipes are sockets and macOS `script`
                         rejects them (tcgetattr fails).
  screens/
    MainScreen.tsx       search, cursor list, multi-select, help overlay
    ConfirmDialog.tsx    install/uninstall/abort confirmation
    RunScreen.tsx        sequential jobs, streamed output, abort, retry
```

The Python side gains one small module, [`allconfigs/probe.py`](../../allconfigs/probe.py), which prints the discovered modules and their detected statuses as NDJSON. Nothing else in the Python package changes.

## Keybindings (same as the Textual TUI)

| Key | Action |
|-----|--------|
| `/` | focus search (esc steps back: search text → search focus → selection) |
| `↑/↓` or `j/k` | move cursor |
| `space` / `x` | toggle module in batch |
| `enter` | install selected (or highlighted) |
| `u` | uninstall selected (config modules are skipped with a note) |
| `a` / `n` / `i` | select all / none / invert (filtered set) |
| `r` | rescan detection |
| `?` | help overlay |
| `q` / ctrl+c | quit |

Run screen: `esc` aborts (with confirm) or goes back when done, `ctrl+r` retries failed jobs. When an installer prints a prompt and waits, a reply box appears — text is sent to the installer's pty and never written to the log.

## Theme

Warm-paper light theme (`src/theme.ts`): sunset gradient wordmark (amber →
orange → coral → rose → pink), espresso ink on `#FBF8F3`, teal accents,
emerald/amber/red statuses. Note: OpenTUI paints empty cells with the
**terminal's default background** — use a light terminal profile (or set the
pane background, as `capture_shots.py` does) for the intended look.

## OpenTUI notes learned while building

- The `focused` prop maps to `focus()`/`blur()`; direct `useKeyboard` handlers run *before* the focused renderable, so a key that focuses an input must call `key.preventDefault()` or the same keystroke lands as text.
- Punctuation key names fall back to the character itself (`/` vs `slash`, `?` vs `question_mark`) depending on the terminal protocol — match both.
- `onSubmit` on `<input>` receives an empty `SubmitEvent`, not the value — track the value via `onInput`.
- `rgba(...)` colors are not parsed (warns, falls back to magenta); use solid colors.
- `key.stopPropagation()` / `preventDefault()` semantics follow the keyboard docs: direct listeners → focused renderable.
