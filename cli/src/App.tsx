import { Component, useCallback, useEffect, useRef, useState, type ReactNode } from "react"
import { discover } from "./bridge"
import type { Job, Module, Plan } from "./types"
import { MainScreen } from "./screens/MainScreen"
import { ConfirmDialog } from "./screens/ConfirmDialog"
import { RunScreen, makeJobs } from "./screens/RunScreen"

export function App(props: { onQuit(): void }) {
  return (
    <ErrorBoundary>
      <Shell {...props} />
    </ErrorBoundary>
  )
}

class ErrorBoundary extends Component<{ children: ReactNode }, { error: string | null }> {
  state = { error: null as string | null }
  static getDerivedStateFromError(err: unknown) {
    return { error: err instanceof Error ? `${err.name}: ${err.message}` : String(err) }
  }
  render() {
    if (this.state.error) {
      return (
        <box style={{ padding: 2 }}>
          <text fg="#ff7a7a">React tree crashed: {this.state.error}</text>
        </box>
      )
    }
    return this.props.children
  }
}

function Shell(props: { onQuit(): void }) {
  const [modules, setModules] = useState<Module[]>([])
  const [platform, setPlatform] = useState("")
  const [loadErrors, setLoadErrors] = useState<string[]>([])
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [screen, setScreen] = useState<"main" | "run">("main")
  const [plan, setPlan] = useState<Plan | null>(null)
  const [run, setRun] = useState<{ action: "install" | "uninstall"; jobs: Job[] } | null>(null)
  const [scanSeq, setScanSeq] = useState(0)

  // RunScreen registers its internal abort here so a confirmed "abort" plan
  // can reach the running pty.
  const abortRef = useRef<(() => void) | null>(null)

  useEffect(() => {
    let cancelled = false
    void discover({
      onEnv: (env) => {
        if (!cancelled) setPlatform(env.platform)
      },
      onError: (message) => {
        if (!cancelled) setLoadErrors((prev) => [...prev, message])
      },
      onModule: (module) => {
        if (cancelled) return
        setModules((prev) => {
          const i = prev.findIndex((m) => m.name === module.name)
          if (i >= 0) {
            const next = [...prev]
            next[i] = module
            return next
          }
          return [...prev, module]
        })
      },
    }).catch(() => {})
    return () => {
      cancelled = true
    }
  }, [scanSeq])

  const rescan = useCallback(() => {
    setModules((prev) => prev.map((m) => ({ ...m, status: "checking" as const })))
    setScanSeq((n) => n + 1)
  }, [])

  const toggle = useCallback((name: string) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(name)) next.delete(name)
      else next.add(name)
      return next
    })
  }, [])

  // MainScreen passes the filtered names so selection ops apply to the
  // visible set, matching the Textual TUI.
  const setVisible = useCallback((mode: "all" | "none" | "invert", names: string[]) => {
    setSelected((prev) => {
      const next = new Set(prev)
      for (const name of names) {
        if (mode === "all") next.add(name)
        else if (mode === "none") next.delete(name)
        else if (next.has(name)) next.delete(name)
        else next.add(name)
      }
      return next
    })
  }, [])

  const requestInstall = useCallback((targets: Module[]) => {
    if (targets.length) setPlan({ action: "install", run: targets, notes: [] })
  }, [])

  const requestUninstall = useCallback((targets: Module[]) => {
    const allowed = targets.filter((m) => m.can_uninstall)
    const blocked = targets.filter((m) => !m.can_uninstall).map((m) => m.name)
    const notes: Plan["notes"] = []
    if (blocked.length) notes.push(["Skipped (config modules or no package to remove):", blocked])
    if (!allowed.length) {
      setLoadErrors((prev) => [...prev, "Nothing to uninstall: " + blocked.join(", ")])
      return
    }
    setPlan({ action: "uninstall", run: allowed, notes })
  }, [])

  const resolvePlan = useCallback(
    (ok: boolean) => {
      const p = plan
      setPlan(null)
      if (!ok || !p) return
      if (p.action === "abort") {
        abortRef.current?.()
        return
      }
      setRun({ action: p.action, jobs: makeJobs(p.run, p.action) })
      setScreen("run")
    },
    [plan],
  )

  const finishRun = useCallback(
    (result: { ok: string[]; failed: string[]; aborted: boolean }) => {
      void result
      setScreen("main")
      setRun(null)
      setSelected((prev) => {
        const next = new Set(prev)
        for (const name of result.ok) next.delete(name)
        return next
      })
      rescan()
    },
    [rescan],
  )

  return (
    <>
      {screen === "main" || !run ? (
        <MainScreen
          modules={modules}
          platform={platform}
          selected={selected}
          loadErrors={loadErrors}
          onToggle={toggle}
          onSetVisible={setVisible}
          onClearSelection={() => setSelected(new Set())}
          onInstall={requestInstall}
          onUninstall={requestUninstall}
          onRescan={rescan}
          onQuit={props.onQuit}
        />
      ) : (
        <RunScreen
          action={run.action}
          jobs={run.jobs}
          registerAbort={(fn) => (abortRef.current = fn)}
          onRequestAbort={(runningModules) => {
            setPlan({ action: "abort", run: runningModules, notes: [] })
          }}
          onFinish={finishRun}
        />
      )}
      {plan && <ConfirmDialog plan={plan} onResolve={resolvePlan} />}
    </>
  )
}
