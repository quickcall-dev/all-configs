# 02 — npm release published

```mermaid
graph TD
    A[Bun/OpenTUI standalone binary] --> B[Platform npm package]
    B --> C[@quickcall/all-configs launcher]
    C --> D[npx @quickcall/all-configs]
    D --> E[Registry processing pending]
    E --> F[Next: configure NPM_TOKEN and tag patch release]
```

## What
- Published public npm packages `@quickcall/all-configs-darwin-arm64@1.0.0` and `@quickcall/all-configs@1.0.0`.
- Added the Node launcher, npm staging script, cross-platform release build script, and npm publishing job.
- Changed Intel macOS CI from the unavailable `macos-13` runner to cross-compilation on `macos-15`.
- Pushed commit `f57fcce` to `main`.

## Key Takeaways
- Bun remains embedded; npm is only the delivery channel.
- macOS arm64 package is 104.5 MB installed and 44.9 MB over npm.
- Local packaged executable smoke test loaded module rows successfully.
- `bun test`: 8 passed, 0 failed; existing React `act(...)` warnings remain.
- npm reports both packages as public via `npm access get status`.

## Current State
- Branch: `main`; pushed commit: `f57fcce` (`release: add npm distribution for TUI binaries`).
- Active experiment: 4.
- Active finding: `docs/experiments/004-release-packaging/findings/01-bun-trim-binary-shrink.md`.
- Published only macOS arm64 at version 1.0.0 because old release downloads stalled and no darwin-x64 artifact existed.
- Registry public reads and `npx` still return E404 while npm processes the new packages.
- CI expects GitHub Actions secret `NPM_TOKEN`, which is not configured/verified.

## Issues
- npm message: `Your package is being processed and may take a few minutes to become available.`
- `npm view`/`npx` currently return `E404 Not Found`; do not republish version 1.0.0 because npm versions are immutable and access status confirms both packages exist/public.
- Linux and Intel Mac npm packages are not published at 1.0.0.
- GitHub release asset downloads from this machine stalled at roughly 1 KB/s.

## Decisions
- Keep Bun/OpenTUI standalone executables; do not change runtime for size alone.
- Use npm optional platform dependencies, following the esbuild-style distribution model.
- Only use Bun trim if a future supported build is much smaller and passes executable/tests.
- Include `modules/`, `lib/`, `allconfigs/`, and `install.sh` in the main npm package, avoiding a first-run git clone.

## Inferred Priority
- **Inferred:** wait for npm processing, verify `npx @quickcall/all-configs`, then configure automated publishing and release all four platforms as a patch version.

## Next
1. Check availability: `npm view @quickcall/all-configs@1.0.0 version`.
2. Once visible, clean smoke test: `npm_config_cache=/tmp/ac-npx npx --yes @quickcall/all-configs@1.0.0` in a real terminal.
3. Create an npm granular automation token with publish access to `@quickcall`, bypass 2FA for automation, then add it as GitHub secret `NPM_TOKEN`.
4. Verify `.github/workflows/release.yml`, then tag a patch release (for example `v1.0.1`) to build/publish all four platforms.
5. Confirm packages with `npm view @quickcall/all-configs-{darwin-arm64,darwin-x64,linux-arm64,linux-x64}@1.0.1 version`.
