---
title: "bun-trim-binary-shrink"
experiment: 004-release-packaging
created: "2026-11-14 18:27 UTC"
---

# Bun executable size and npm delivery

## Finding

The large executable is primarily Bun/JavaScriptCore, not application code.
A local macOS arm64 build was approximately 100 MB raw and 45 MB compressed;
`strip` produced no meaningful reduction. OpenTUI officially recommends
`bun build --compile` when a self-contained target-specific executable is
desired.

Bun documents an experimental AOT `--trim` path that can remove unused runtime
features, but Bun 1.4.4 does not expose the documented `bun compile --trim`
workflow. No release should switch to trimming until a candidate build is both
substantially smaller and passes the real executable smoke test and TUI suite.

## Decision

Keep Bun and the standalone executable. Improve delivery through npm rather
than changing runtimes:

```text
@quickcall/all-configs
  -> optional platform package
  -> embedded Bun/OpenTUI executable
  -> packaged module definitions and install scripts
```

Users run `npx @quickcall/all-configs`; they do not install Bun.

## Verification

- Packaged macOS arm64 executable: 104.5 MB unpacked, 44.9 MB npm tarball.
- Smoke test started the executable in a pseudo-terminal and loaded module rows.
- `bun test`: 8 passed, 0 failed (existing React `act(...)` warnings remain).
- Published `@quickcall/all-configs-darwin-arm64@1.0.0` and
  `@quickcall/all-configs@1.0.0`; npm reported that registry processing may
  take several minutes before public reads stop returning 404.

## Follow-up

- Configure repository secret `NPM_TOKEN` with publish access to `@quickcall`.
- Tag the next patch release to build and publish darwin arm64/x64 and Linux
  arm64/x64 packages through `.github/workflows/release.yml`.
- Revisit Bun trimming only when stable/canary support is available and retain
  it only if the size reduction is large and the compiled application works.
