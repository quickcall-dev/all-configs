# Releasing

How all-configs ships. TL;DR: **push a `v*` tag → CI builds binaries → GitHub
Release + npm platform packages → users run `npx @quickcall/all-configs`.**

## The flow

1. Land work on `main` and push.
2. Tag a version and push it:

   ```bash
   git tag -a v1.1.0 -m "what's new"
   git push origin v1.1.0
   ```

3. `.github/workflows/release.yml` runs a matrix build
   (darwin-arm64/x64, linux-x64/arm64): installs the matching OpenTUI native
   package, compiles the TUI with `bun build --compile`, and attaches each
   compressed binary to a GitHub Release.
4. CI packages the npm release — a **single** `@quickcall/all-configs`
   package (launcher + module runtime). No per-platform npm packages: the
   launcher downloads `all-configs-tui-<os>-<arch>` from the matching
   GitHub Release on install (postinstall) or first run and caches it.
   Users run `npx @quickcall/all-configs`; Bun is embedded and is not
   required on their machine.
5. `scripts/install.sh` remains supported and downloads
   `releases/latest/download/all-configs-tui-<os>-<arch>`. Re-running it on an
   installed machine upgrades the canonical clone and binary.

The repository must have an npm automation token stored as the GitHub Actions
secret `NPM_TOKEN`. The token needs publish access to the `@quickcall` scope.

Version numbers are plain semver tags; the `v` prefix is required. The tag is
baked into each binary at build time (`ALL_CONFIGS_VERSION`), so
`all-configs --version` (and the `?` help screen) reports exactly what is
installed; the npm launcher answers `--version` from its own `package.json`.

## What the binary is

`cli/src/index.tsx` compiled by `bun build --compile` —
the Bun runtime and OpenTUI's native library are embedded, so the target
machine needs nothing but the binary, `uv` (module detection), and the repo
(modules + install scripts) which the installer clones to `~/.all-configs`.
The app code is under 1 MB; the ~100 MB is the embedded JS runtime. Assets
are gzip-compressed (`-9`, roughly 3x smaller) and decompressed by the
installer.

The binary finds the repo by, in order:

1. `$ALL_CONFIGS_ROOT`
2. walking up from the executable / cwd to a directory containing
   `modules/` and `lib/common.sh` (the installer places the binary inside
   the clone at `~/.all-configs/bin/`)
3. the dev layout (`import.meta.dir` three levels up)

Build locally:

```bash
cd cli
bun run build-release.ts bun-darwin-arm64 ac-tui
ALL_CONFIGS_VERSION=dev ALL_CONFIGS_ROOT=/path/to/repo ./ac-tui
```

Prepare npm packages from a directory of release binaries:

```bash
scripts/prepare-npm-packages.sh 1.1.0 /tmp/npm-package
```

## Test a release before tagging

The same command the CI runs works locally (see above), and
`cli/test` (`bun test`) covers the app end to end,
including a real install through the run screen.
