# Releasing

How all-configs ships. TL;DR: **push a `v*` tag → CI builds binaries → GitHub
Release → installers fetch from `releases/latest/download/`.**

## The flow

1. Land work on `main` and push.
2. Tag a version and push it:

   ```bash
   git tag -a v1.1.0 -m "what's new"
   git push origin v1.1.0
   ```

3. `.github/workflows/release.yml` runs a matrix build
   (darwin-arm64/x64, linux-x64/arm64): installs deps, compiles the TUI with
   `bun build --compile`, and attaches each binary to a GitHub Release for
   that tag. The release appears at
   `https://github.com/quickcall-dev/all-configs/releases`.
4. `scripts/install.sh` downloads
   `releases/latest/download/all-configs-tui-<os>-<arch>`, so every new
   release becomes the default for new installs automatically. Re-running
   the installer on an installed machine upgrades it.

Version numbers are plain semver tags; the `v` prefix is required.

## What the binary is

`experimental/opentui/src/index.tsx` compiled by `bun build --compile` —
the Bun runtime and OpenTUI's native library are embedded, so the target
machine needs nothing but the binary, `uv` (module detection), and the repo
(modules + install scripts) which the installer clones to `~/.all-configs`.

The binary finds the repo by, in order:

1. `$ALL_CONFIGS_ROOT`
2. walking up from the executable / cwd to a directory containing
   `modules/` and `lib/common.sh` (the installer places the binary inside
   the clone at `~/.all-configs/bin/`)
3. the dev layout (`import.meta.dir` three levels up)

Build locally:

```bash
cd experimental/opentui
bun build --compile --target=bun-darwin-arm64 src/index.tsx --outfile ac-tui
ALL_CONFIGS_ROOT=/path/to/repo ./ac-tui
```

## Test a release before tagging

The same command the CI runs works locally (see above), and
`experimental/opentui/test` (`bun test`) covers the app end to end,
including a real install through the run screen.
