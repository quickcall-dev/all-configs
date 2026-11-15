/**
 * Bridge to the Python side of all-configs.
 *
 * Discovery/detection delegates to `allconfigs.probe` (same logic the Textual
 * TUI uses) and streams results as NDJSON. Jobs run under `script(1)` so the
 * child gets a real pty: colors stay on and sudo/read prompts reach the user.
 * Writing to the child's stdin (replies) goes through the pty master.
 */
import { dlopen, FFIType } from "bun:ffi"
import { closeSync, openSync, writeSync } from "node:fs"
import type { Module } from "./types"

/**
 * Where the all-configs repo lives. Resolution order:
 *  1. $ALL_CONFIGS_ROOT (explicit override)
 *  2. walk up from the executable / cwd looking for the repo markers
 *     (modules/ + lib/common.sh) — finds the canonical install when the
 *     released binary lives somewhere inside the repo
 *  3. the dev layout: src/ -> cli/ -> repo root
 */
export const REPO_ROOT = (() => {
  if (process.env.ALL_CONFIGS_ROOT) {
    return process.env.ALL_CONFIGS_ROOT.replace(/\/$/, "")
  }
  const { readdirSync, existsSync } = require("node:fs") as typeof import("node:fs")
  const { dirname, resolve } = require("node:path") as typeof import("node:path")
  const isRepo = (dir: string) => {
    try {
      return existsSync(`${dir}/lib/common.sh`) && readdirSync(`${dir}/modules`).length > 0
    } catch {
      return false
    }
  }
  const startPoints = [dirname(process.execPath), process.cwd(), import.meta.dir]
  for (const start of startPoints) {
    let dir = resolve(start)
    for (let i = 0; i < 6 && dir !== "/"; i++) {
      if (isRepo(dir)) return dir
      dir = dirname(dir)
    }
  }
  // dev fallback
  let dir = import.meta.dir
  for (let i = 0; i < 3; i++) dir = dir.substring(0, dir.lastIndexOf("/"))
  return dir
})()

const PYTHON = ["uv", "run", "--quiet", "--no-project", "--python", "3.12", "python3"]

export interface DiscoverEvents {
  onEnv?: (env: { platform: string; root: string }) => void
  onModule: (module: Module) => void
  onError?: (message: string) => void
}

/** Stream module discovery. Resolves when every module has been reported. */
export async function discover(events: DiscoverEvents): Promise<void> {
  const proc = Bun.spawn([...PYTHON, "-m", "allconfigs.probe", REPO_ROOT], {
    cwd: REPO_ROOT,
    stdout: "pipe",
    stderr: "pipe",
  })
  const decoder = new TextDecoder()
  let partial = ""
  const handle = (text: string) => {
    partial += text
    const lines = partial.split("\n")
    partial = lines.pop() ?? ""
    for (const line of lines) {
      if (!line.trim()) continue
      let payload: any
      try {
        payload = JSON.parse(line)
      } catch {
        continue
      }
      if (payload.type === "module") events.onModule(payload.module as Module)
      else if (payload.type === "env") events.onEnv?.(payload)
      else if (payload.type === "error") events.onError?.(payload.message)
    }
  }
  for await (const chunk of proc.stdout) handle(decoder.decode(chunk, { stream: true }))
  handle(decoder.decode())
  await proc.exited
}

// ─── Jobs ──────────────────────────────────────────────────────────────────

export interface JobHandle {
  write(text: string): void
  /** SIGKILL the pty wrapper; the closed pty SIGHUPs the foreground group. */
  kill(): void
  /** Resolves with the child's exit code. */
  done: Promise<number>
}

export interface JobEvents {
  onLine(line: string): void
  /** Current unfinished line (progress bars overwrite via \r). */
  onPartial(partial: string): void
  onExit(code: number): void
}

// ─── Reply pty ─────────────────────────────────────────────────────────────
//
// `script` forwards its own stdin to the child. Bun's pipes are sockets and
// macOS `script` refuses them (tcgetattr fails), so we allocate a real pty
// and hand `script` the slave end. Replies written to the master reach the
// installer's prompt.

interface PtyPair {
  masterFd: number
  slaveFd: number
}

function openReplyPty(): PtyPair | null {
  try {
    const lib = dlopen(process.platform === "darwin" ? "/usr/lib/libSystem.B.dylib" : "libc.so.6", {
      posix_openpt: { args: [FFIType.i32], returns: FFIType.i32 },
      grantpt: { args: [FFIType.i32], returns: FFIType.i32 },
      unlockpt: { args: [FFIType.i32], returns: FFIType.i32 },
      ptsname: { args: [FFIType.i32], returns: FFIType.cstring },
    })
    const O_RDWR = 0x2
    const O_NOCTTY = process.platform === "darwin" ? 0x20000 : 0x200
    const master = lib.symbols.posix_openpt(O_RDWR | O_NOCTTY)
    if (master < 0) return null
    if (lib.symbols.grantpt(master) !== 0) return null
    if (lib.symbols.unlockpt(master) !== 0) return null
    const path = lib.symbols.ptsname(master)
    if (!path) return null
    const slave = openSync(path, "r+")
    return { masterFd: master, slaveFd: slave }
  } catch {
    return null
  }
}

export interface LineBuffer {
  partial: string
}

export function makeLineBuffer(): LineBuffer {
  return { partial: "" }
}

/**
 * Feed raw pty output. Complete lines have carriage returns collapsed
 * (progress bars overwrite via \r: only the text after the last one
 * survives). `buffer.partial` keeps the unfinished tail for the next feed.
 */
export function feedLines(
  buffer: LineBuffer,
  text: string,
): { lines: string[]; display: string } {
  // A pty ends lines with \r\n; progress bars overwrite with bare \r.
  // Strip trailing \r first, then keep only what follows the last \r.
  const collapse = (l: string) => {
    const stripped = l.replace(/\r+$/, "")
    return stripped.slice(stripped.lastIndexOf("\r") + 1)
  }
  const parts = (buffer.partial + text).split("\n")
  buffer.partial = parts.pop() ?? ""
  return { lines: parts.map(collapse), display: collapse(buffer.partial) }
}

export function runJob(argv: string[], events: JobEvents): JobHandle {
  // macOS `script -q /dev/null <cmd...>` allocates a pty for the child.
  const pty = openReplyPty()
  // `script` rejects socket stdin (Bun pipes are sockets and its tcgetattr
  // fails); a real pty slave keeps typed replies flowing to the installer.
  const stdio: [number, "pipe", "pipe"] | ["ignore", "pipe", "pipe"] = pty
    ? [pty.slaveFd, "pipe", "pipe"]
    : ["ignore", "pipe", "pipe"]
  const proc = Bun.spawn(["script", "-q", "/dev/null", ...argv], {
    cwd: REPO_ROOT,
    env: { ...process.env, TERM: "xterm-256color", ALL_CONFIGS_TUI: "1" } as Record<string, string>,
    stdio: stdio as [number, "pipe", "pipe", ...unknown[]],
  })
  if (pty) closeSync(pty.slaveFd)

  const done = (async () => {
    const code = await proc.exited
    events.onExit(code)
    return code
  })()

  ;(async () => {
    const decoder = new TextDecoder()
    const buffer = makeLineBuffer()
    for await (const chunk of proc.stdout) {
      const { lines, display } = feedLines(buffer, decoder.decode(chunk, { stream: true }))
      for (const line of lines) events.onLine(line)
      events.onPartial(display)
    }
    const { lines, display } = feedLines(buffer, decoder.decode())
    for (const line of lines) events.onLine(line)
    events.onPartial(display)
  })().catch(() => {})

  return {
    write(text: string) {
      if (!pty) return
      try {
        writeSync(pty.masterFd, text)
      } catch {}
    },
    kill() {
      proc.kill("SIGKILL")
    },
    done: done.finally(() => {
      if (pty) {
        try {
          closeSync(pty.masterFd)
        } catch {}
      }
    }),
  }
}

const ANSI_RE = /\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[@-Z\\-_]|\x1b\[[0-?]*[ -/]*[@-~]/g

/** Strip terminal escape sequences for the plain-text log file. */
export function stripAnsi(text: string): string {
  return text.replace(ANSI_RE, "")
}

export function jobArgv(action: "install" | "uninstall", module: Module): string[] {
  if (action === "install") return ["bash", `${REPO_ROOT}/modules/${module.name}/install.sh`]
  return ["bash", `${REPO_ROOT}/lib/uninstall.sh`, ...module.uninstall_packages]
}

export function logDir(): string {
  const base = process.env.XDG_STATE_HOME ?? `${process.env.HOME}/.local/state`
  return `${base}/all-configs/logs`
}
