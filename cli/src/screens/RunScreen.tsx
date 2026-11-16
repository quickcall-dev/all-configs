import { useEffect, useRef, useState } from "react"
import { useKeyboard, useRenderer } from "@opentui/react"
import { appendFileSync, mkdirSync } from "node:fs"
import type { Job, Module } from "../types"
import { jobArgv, logDir, runJob, stripAnsi, type JobHandle } from "../bridge"
import { theme } from "../theme"
import { MiniWordmark } from "../components/Wordmark"

// Braille frames render as hollow boxes in some fonts; the circle set
// (◐◓◑◒) is present in Menlo and every Nerd Font.
const SPINNER = "◐◓◑◒"
const MAX_LINES = 4000
const PROMPT_RE = /[:?>\]\)]\s*$/
const PASSWORD_RE = /(password|passphrase|passcode)\b[^\n]*[:?]\s*$/i

const BADGE: Record<Job["state"], { glyph: string; color: string }> = {
  pending: { glyph: "○", color: theme.muted },
  running: { glyph: "", color: theme.accent },
  ok: { glyph: "✓", color: theme.ok },
  failed: { glyph: "✗", color: theme.err },
  skipped: { glyph: "–", color: theme.muted },
}

export interface RunScreenProps {
  action: "install" | "uninstall"
  jobs: Job[]
  registerAbort(fn: () => void): void
  onRequestAbort(running: Module[]): void
  onFinish(result: { ok: string[]; failed: string[]; aborted: boolean }): void
}

export function RunScreen(props: RunScreenProps) {
  const renderer = useRenderer()
  const [jobs, setJobs] = useState<Job[]>(props.jobs)
  const [lines, setLines] = useState<string[]>([])
  const [live, setLive] = useState("")
  const [copied, setCopied] = useState(false)
  const [running, setRunning] = useState(true)
  const [aborted, setAborted] = useState(false)
  const [replyFocused, setReplyFocused] = useState(false)
  const [replyValue, setReplyValue] = useState("")
  const [logPath, setLogPath] = useState<string | null>(null)
  const [tick, setTick] = useState(0)
  const [replyKey, setReplyKey] = useState(0)
  const [bar, setBar] = useState({ top: 0, height: 0, view: 0 })
  const scrollRef = useRef<any>(null)

  const handleRef = useRef<JobHandle | null>(null)
  const abortingRef = useRef(false)
  const startedRef = useRef(Date.now())
  const waitingRef = useRef<{ since: number } | null>(null)
  const linesRef = useRef<string[]>([])
  const logPathRef = useRef<string | null>(null)
  const jobsRef = useRef<Job[]>(jobs)
  jobsRef.current = jobs

  useEffect(() => {
    const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19)
    const dir = logDir()
    try {
      mkdirSync(dir, { recursive: true })
      const path = `${dir}/${stamp}-${props.action}.log`
      appendFileSync(path, "")
      logPathRef.current = path
      setLogPath(path)
    } catch {
      logPathRef.current = null
      setLogPath(null)
    }
    void runAll(props.jobs)
    const timer = setInterval(() => {
      setTick((t) => t + 1)
      // Prompt detection: partial line that looks like a question and has
      // been idle for a moment means the installer waits for input.
      const now = Date.now()
      if (waitingRef.current && now - waitingRef.current.since > 1200) {
        setReplyFocused(true)
      }
      // Custom minimal scrollbar: read the native scroll state.
      const sb = scrollRef.current
      if (sb) {
        const view = sb.height ?? 0
        const total = sb.scrollHeight ?? 0
        const max = Math.max(0, total - view)
        // One-cell slider: a single small rectangle marks the position.
        const thumbH = total > view ? 1 : 0
        const thumbTop = max > 0 ? Math.round(((sb.scrollTop ?? 0) / max) * Math.max(0, view - thumbH)) : 0
        setBar((prev) =>
          prev.top === thumbTop && prev.height === thumbH && prev.view === view
            ? prev
            : { top: thumbTop, height: thumbH, view },
        )
      }
    }, 400)
    return () => clearInterval(timer)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const writeLog = (line: string) => {
    linesRef.current = [...linesRef.current, line].slice(-MAX_LINES)
    setLines(linesRef.current)
    if (logPathRef.current) {
      try {
        appendFileSync(logPathRef.current, stripAnsi(line) + "\n")
      } catch {}
    }
  }

  const say = (line: string) => writeLog(line)

  const patchJob = (name: string, patch: Partial<Job>) => {
    setJobs((prev) => prev.map((j) => (j.module.name === name ? { ...j, ...patch } : j)))
  }

  const runAll = async (jobs: Job[]) => {
    setRunning(true)
    abortingRef.current = false
    const outcomes: Array<{ job: Job; code: number }> = []
    for (const job of jobs) {
      if (abortingRef.current) {
        patchJob(job.module.name, { state: "skipped" })
        outcomes.push({ job, code: -1 })
        continue
      }
      outcomes.push({ job, code: await runOne(job) })
    }
    setRunning(false)
    setReplyFocused(false)
    setLive("")
    const failed = outcomes.filter((o) => o.code !== 0 && o.code !== -1).map((o) => o.job.module.name)
    const skipped = outcomes.filter((o) => o.code === -1).length
    say("")
    if (abortingRef.current || skipped > 0) {
      say("■ Aborted.")
    } else if (failed.length) {
      say(`✗ Finished with ${failed.length} failed: ${failed.join(", ")}`)
    } else {
      say(`✓ All ${outcomes.length} finished successfully.`)
    }
    if (logPathRef.current) say(`  log  ${logPathRef.current.replace(process.env.HOME ?? "", "~")}`)
  }

  const runOne = (job: Job): Promise<number> =>
    new Promise((resolve) => {
      patchJob(job.module.name, { state: "running", seconds: 0 })
      startedRef.current = Date.now()
      say("")
      say(`── ${job.module.name} ──`)
      const argv = jobArgv(props.action, job.module)
      const handle = runJob(argv, {
        onLine: (line) => {
          waitingRef.current = null
          setReplyFocused(false)
          writeLog(stripAnsi(line))
          setLive("")
        },
        onPartial: (partial) => {
          const plain = stripAnsi(partial)
          setLive(plain)
          waitingRef.current = PROMPT_RE.test(plain) ? { since: Date.now() } : null
        },
        onExit: (code) => {
          const seconds = (Date.now() - startedRef.current) / 1000
          patchJob(job.module.name, {
            state: code === 0 ? "ok" : "failed",
            seconds,
            returncode: code,
          })
          if (code !== 0) say(`✗ ${job.module.name} exited with ${code}`)
          handleRef.current = null
          setReplyFocused(false)
          setLive("")
          resolve(code)
        },
      })
      handleRef.current = handle
    })

  const abort = () => {
    if (!running) return
    abortingRef.current = true
    setAborted(true)
    say("Aborting: stopping current step, skipping the rest…")
    handleRef.current?.kill()
  }

  const retryFailed = () => {
    if (running) return
    const failed = jobsRef.current.filter((j) => j.state === "failed")
    if (!failed.length) return
    for (const j of failed) patchJob(j.module.name, { state: "pending" })
    void runAll(failed)
  }

  const copyLog = () => {
    // OSC52 works over plain SSH (terminal permitting); it is the only
    // clipboard mechanism available on a remote host.
    const text = linesRef.current.join("\n")
    // Keep the OSC52 payload well under the ~74KB safe base64 limit.
    const clipped = text.length > 50000 ? text.slice(-50000) : text
    const sent = (renderer as unknown as { copyToClipboardOSC52?: (t: string) => boolean })
      .copyToClipboardOSC52?.(clipped)
    setCopied(sent === true)
    setTimeout(() => setCopied(false), 3000)
  }

  useKeyboard((key) => {
    if (key.name === "c" && !replyFocused) {
      copyLog()
      return
    }
    if (key.ctrl && key.name === "r") {
      retryFailed()
      return
    }
    if (key.name === "escape") {
      if (running) {
        const active = jobsRef.current.filter((j) => j.state === "running").map((j) => j.module)
        props.onRequestAbort(active)
      } else {
        finish()
      }
    }
  })

  const finish = () => {
    const final = jobsRef.current
    props.onFinish({
      ok: final.filter((j) => j.state === "ok").map((j) => j.module.name),
      failed: final.filter((j) => j.state === "failed").map((j) => j.module.name),
      aborted,
    })
  }

  useEffect(() => {
    props.registerAbort(abort)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [running])

  // spinner frames advance with the tick
  void tick
  const done = jobs.filter((j) => ["ok", "failed", "skipped"].includes(j.state)).length
  const failedCount = jobs.filter((j) => j.state === "failed").length
  const spinner = SPINNER[Math.floor(Date.now() / 100) % SPINNER.length]

  return (
    <box
      style={{
        width: "100%",
        height: "100%",
        flexDirection: "column",
        backgroundColor: theme.bg,
        paddingLeft: 1,
        paddingRight: 1,
      }}
    >
      {/* header */}
      <box style={{ flexDirection: "row", marginTop: 1, marginBottom: 1 }}>
        <MiniWordmark />
        <text fg={theme.muted}>  </text>
        <text fg={theme.accent}>›</text>
        <text fg={theme.text}> {props.action}</text>
        <text fg={theme.muted}>    </text>
        <text fg={theme.text}>{done}/{jobs.length}</text>
        <text fg={theme.muted}> done</text>
        {failedCount > 0 && <text fg={theme.err}>  ·  {failedCount} failed</text>}
      </box>

      {/* body: steps sidebar + log, no boxes */}
      <box style={{ flexDirection: "row", flexGrow: 1 }}>
        <box
          style={{
            width: 30,
            height: "100%",
            flexDirection: "column",
            paddingTop: 1,
          }}
        >
          <text fg={theme.faint}>  STEPS  {done}/{jobs.length}</text>
          <box style={{ height: 1 }} />
          {jobs.map((j) => {
            const badge = BADGE[j.state]
            const glyph = j.state === "running" ? spinner : badge.glyph
            const secs =
              j.state === "running" || j.state === "ok" || j.state === "failed"
                ? `${j.seconds.toFixed(0)}s`
                : ""
            const color =
              j.state === "running"
                ? theme.accent2
                : j.state === "pending" || j.state === "skipped"
                  ? theme.muted
                  : badge.color
            return (
              <box key={j.module.name} style={{ flexDirection: "row", height: 1 }}>
                <text fg={color}>
                  {glyph} {j.module.name.slice(0, 20).padEnd(22)}
                </text>
                <text fg={theme.muted}>{secs.padStart(4)}</text>
              </box>
            )
          })}
        </box>

        <box style={{ width: 2 }} />

        <box
          style={{
            flexGrow: 1,
            height: "100%",
            flexDirection: "column",
            paddingTop: 1,
          }}
        >
          <box style={{ flexDirection: "row", flexGrow: 1, height: "100%" }}>
            <scrollbox
              ref={scrollRef}
              style={{ flexGrow: 1, height: "100%" }}
              stickyScroll
              stickyStart="bottom"
              verticalScrollbarOptions={{ visible: false } as any}
            >
              <box style={{ flexDirection: "column", paddingRight: 1 }}>
                {lines.map((l, i) => (
                  <text key={i} fg={theme.text}>
                    {l || " "}
                  </text>
                ))}
              </box>
            </scrollbox>
            {/* minimal scrollbar: a single-cell slider, no track */}
            {bar.height > 0 && bar.view > 0 && (
              <box style={{ width: 1, height: "100%", flexDirection: "column" }}>
                {Array.from({ length: bar.view }, (_, i) => (
                  <text key={i} fg={theme.accent2}>
                    {i >= bar.top && i < bar.top + bar.height ? "▌" : " "}
                  </text>
                ))}
              </box>
            )}
          </box>
          {live !== "" && (
            <box style={{ height: 1, paddingLeft: 1 }}>
              <text fg={theme.muted}>{live}</text>
            </box>
          )}
          {replyFocused && (
            <box style={{ flexDirection: "row", height: 1, paddingLeft: 1, paddingRight: 1 }}>
              <text fg={theme.warn}>reply› </text>
              <input
                key={replyKey}
                placeholder="sent to the installer, never logged"
                width={50}
                focused={replyFocused}
                onInput={setReplyValue}
                onSubmit={() => {
                  handleRef.current?.write(replyValue + "\n")
                  setReplyValue("")
                  setReplyFocused(false)
                  setReplyKey((k) => k + 1)
                  waitingRef.current = null
                }}
                textColor={theme.text}
              />
            </box>
          )}
        </box>
      </box>

      {/* bottom bar */}
      <box style={{ flexDirection: "row", height: 1, marginTop: 1, marginBottom: 1 }}>
        <text fg={theme.muted}>
          {running ? "  esc abort" : "  esc back · ctrl+r retry failed"}
          {"  ·  c copy log"}
          {copied ? "  ·  ✓ copied (osc52)" : ""}
          {logPath ? `  ·  log ${logPath.replace(process.env.HOME ?? "", "~")}` : ""}
        </text>
      </box>
    </box>
  )
}

export function makeJobs(modules: Module[], action: "install" | "uninstall"): Job[] {
  return modules.map((m) => ({
    module: m,
    argv: jobArgv(action, m),
    state: "pending" as const,
    seconds: 0,
    returncode: null,
  }))
}

