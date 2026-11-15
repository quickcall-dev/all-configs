export type ModuleStatus = "checking" | "installed" | "partial" | "missing" | "unknown"
export type Action = "install" | "uninstall"
export type JobState = "pending" | "running" | "ok" | "failed" | "skipped"

export interface Module {
  name: string
  description: string
  kind: string
  platforms: string[]
  status: ModuleStatus
  can_uninstall: boolean
  uninstall_packages: string[]
}

export interface Plan {
  action: Action | "abort"
  /** Modules the plan will act on. */
  run: Module[]
  /** Warnings shown under the list (e.g. skipped config modules). */
  notes: Array<[title: string, names: string[]]>
}

export interface Job {
  module: Module
  argv: string[]
  state: JobState
  seconds: number
  returncode: number | null
}

export const STATUS_LABEL: Record<ModuleStatus, string> = {
  checking: "…",
  installed: "installed",
  partial: "partial",
  missing: "missing",
  unknown: "unknown",
}
