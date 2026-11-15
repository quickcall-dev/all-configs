import { useKeyboard, useTerminalDimensions } from "@opentui/react"
import type { InputRenderable } from "@opentui/core"
import { useMemo, useRef, useState } from "react"
import type { Module } from "../types"
import { STATUS_LABEL } from "../types"
import { theme } from "../theme"
import { Wordmark } from "../components/Wordmark"
import { HelpView } from "../components/Help"

export interface MainScreenProps {
  modules: Module[]
  platform: string
  selected: Set<string>
  loadErrors: string[]
  onToggle(name: string): void
  onSetVisible(mode: "all" | "none" | "invert", names: string[]): void
  onClearSelection(): void
  onInstall(targets: Module[]): void
  onUninstall(targets: Module[]): void
  onRescan(): void
  onQuit(): void
}

const STATUS_COLOR: Record<string, string> = {
  installed: theme.ok,
  partial: theme.warn,
  missing: theme.muted,
  unknown: theme.muted,
  checking: theme.accent,
}

export function visibleModules(modules: Module[], query: string): Module[] {
  const q = query.trim().toLowerCase()
  if (!q) return modules
  return modules.filter(
    (m) =>
      m.name.toLowerCase().includes(q) ||
      m.description.toLowerCase().includes(q) ||
      m.kind === q ||
      m.status === q,
  )
}

function truncate(text: string, width: number): string {
  if (width <= 0) return ""
  return text.length > width ? text.slice(0, Math.max(1, width - 1)) + "…" : text
}

export function MainScreen(props: MainScreenProps) {
  const { width, height } = useTerminalDimensions()
  const [search, setSearch] = useState("")
  const [searchFocused, setSearchFocused] = useState(false)
  const [cursor, setCursor] = useState(0)
  const [help, setHelp] = useState(false)
  const inputRef = useRef<InputRenderable | null>(null)

  const clearSearch = () => {
    // Assigning "" emits INPUT, which syncs the filter state too.
    if (inputRef.current) inputRef.current.value = ""
    setSearch("")
    setCursor(0)
  }

  const rows = useMemo(() => visibleModules(props.modules, search), [props.modules, search])
  const clampedCursor = Math.min(cursor, Math.max(0, rows.length - 1))
  const cursorModule = rows[clampedCursor]

  const nameW = Math.max(10, ...props.modules.map((m) => m.name.length))
  const statusW = 9
  const descW = Math.max(12, width - (2 + nameW + 8 + statusW + 6 + 2))

  const installed = props.modules.filter((m) => m.status === "installed").length
  const selNames = props.modules.filter((m) => props.selected.has(m.name)).map((m) => m.name)

  const focusSearch = () => {
    setSearchFocused(true)
    inputRef.current?.focus()
  }
  const blurSearch = () => {
    setSearchFocused(false)
    inputRef.current?.blur()
  }

  const targets = (): Module[] => {
    const chosen = props.modules.filter((m) => props.selected.has(m.name))
    if (chosen.length) return chosen
    return cursorModule ? [cursorModule] : []
  }

  const move = (delta: number) => setCursor((c) => Math.min(Math.max(0, c + delta), Math.max(0, rows.length - 1)))

  useKeyboard((key) => {
    if (help) {
      if (key.name === "escape" || key.name === "q" || key.name === "question_mark" || key.sequence === "?") setHelp(false)
      return
    }

    if (searchFocused) {
      // esc layering: search text, then search focus, then selection
      if (key.name === "escape") {
        if (search) clearSearch()
        else blurSearch()
      } else if (key.name === "return") {
        blurSearch()
      } else if (key.name === "down") {
        blurSearch()
        move(1)
      }
      return // everything else goes to the input
    }

    switch (key.name) {
      case "escape":
        // Same layering with the input blurred: stale search text goes
        // first, so a batch selection survives an esc meant for the filter.
        if (search) clearSearch()
        else if (props.selected.size) props.onClearSelection()
        break
      case "slash":
      case "/":
        focusSearch()
        // The same keystroke must not end up as text in the freshly focused input.
        key.preventDefault()
        break
      case "up":
      case "k":
        move(-1)
        break
      case "down":
      case "j":
        move(1)
        break
      case "space":
      case "x":
        if (cursorModule) props.onToggle(cursorModule.name)
        break
      case "a":
        props.onSetVisible("all", rows.map((m) => m.name))
        break
      case "n":
        props.onSetVisible("none", rows.map((m) => m.name))
        break
      case "i":
        props.onSetVisible("invert", rows.map((m) => m.name))
        break
      case "return":
        props.onInstall(targets())
        break
      case "u":
        props.onUninstall(targets())
        break
      case "r":
        props.onRescan()
        break
      case "question_mark":
      case "?":
        setHelp(true)
        break
      case "q":
        props.onQuit()
        break
    }
  })

  const listHeight = Math.max(4, height - 13) // header, search, list label, bars, footer
  const page = listHeight - 2
  const start = Math.min(Math.max(0, clampedCursor - page + 1), Math.max(0, rows.length - page))

  // help takes over the whole screen; keys to close are handled above
  if (help) return <HelpView />

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
      {/* header: wordmark left, meta right */}
      <box style={{ flexDirection: "row", marginTop: 1, marginBottom: 1 }}>
        <Wordmark />
        <box
          style={{
            flexGrow: 1,
            height: 2,
            flexDirection: "column",
            alignItems: "flex-end",
            justifyContent: "center",
          }}
        >
          <text>
            <span fg={theme.ok}>{String(installed).padStart(2, " ")}</span>
            <span fg={theme.faint}> / </span>
            <span fg={theme.text}>{props.modules.length}</span>
            <span fg={theme.muted}>  installed</span>
          </text>
          <text fg={theme.muted}>
            {props.platform} · apps · cli · config
          </text>
        </box>
      </box>

      {/* search */}
      <box style={{ flexDirection: "row", height: 1, marginBottom: 1 }}>
        <text fg={searchFocused ? theme.accent : theme.muted}>/ </text>
        <input
          ref={inputRef}
          placeholder="search name, description, kind or status"
          width={Math.max(30, Math.min(60, width - 6))}
          onInput={(value: string) => {
            setSearch(value)
            setCursor(0)
          }}
          onSubmit={() => blurSearch()}
          textColor={theme.text}
          focused={searchFocused}
        />
      </box>

      {/* list label + modules, no box */}
      <text fg={theme.faint}>
        {`  MODULES${rows.length !== props.modules.length ? `  ${rows.length}/${props.modules.length}` : ""}`}
      </text>
      <box style={{ flexDirection: "column", flexGrow: 1, height: listHeight - 1 }}>
        {rows.length === 0 ? (
          <text fg={theme.muted}>
            {"  "}No module matches “{search}”. esc clears the search
          </text>
        ) : (
          rows.slice(start, start + page).map((m, i) => {
            const picked = props.selected.has(m.name)
            const active = start + i === clampedCursor && !searchFocused
            return (
              <box
                key={m.name}
                style={{
                  flexDirection: "row",
                  height: 1,
                  width: "100%",
                  backgroundColor: active ? theme.highlight : theme.bg,
                }}
              >
                <text fg={picked ? theme.accent : theme.muted}>{picked ? "▍" : " "}</text>
                <text fg={picked ? theme.accent : theme.text}>
                  {truncate(m.name, nameW).padEnd(nameW)}
                </text>
                <text fg={theme.muted}>{"  "}</text>
                <text fg={theme.muted}>{m.kind.padEnd(6).slice(0, 6)}</text>
                <text fg={theme.muted}>{"  "}</text>
                <text fg={STATUS_COLOR[m.status]}>
                  {truncate(STATUS_LABEL[m.status], statusW).padEnd(statusW)}
                </text>
                <text fg={theme.muted}>{"  "}</text>
                <text fg={theme.muted}>{truncate(m.description, descW)}</text>
              </box>
            )
          })
        )}
      </box>

      {/* selection bar */}
      <box style={{ height: 1, marginTop: 1 }}>
        {selNames.length ? (
          <text>
            <span fg={theme.accent}>{selNames.length} selected</span>
            <span fg={theme.text}>  {selNames.slice(0, 6).join(" · ")}{selNames.length > 6 ? " …" : ""}</span>
          </text>
        ) : (
          <text fg={theme.muted}>
            Nothing selected. enter installs the highlighted module, space adds it to a batch.
          </text>
        )}
      </box>

      {/* footer */}
      <box style={{ flexDirection: "row", height: 1, marginTop: 1, marginBottom: 1 }}>
        <text>
          <span fg={theme.faint}>  </span>
          <span fg={theme.accent2}>/</span>
          <span fg={theme.muted}> search  </span>
          <span fg={theme.accent2}>⏎</span>
          <span fg={theme.muted}> install  </span>
          <span fg={theme.accent2}>u</span>
          <span fg={theme.muted}> uninstall  </span>
          <span fg={theme.accent2}>space</span>
          <span fg={theme.muted}> select  </span>
          <span fg={theme.accent2}>a·n·i</span>
          <span fg={theme.muted}> batch  </span>
          <span fg={theme.accent2}>r</span>
          <span fg={theme.muted}> rescan  </span>
          <span fg={theme.accent2}>?</span>
          <span fg={theme.muted}> help  </span>
          <span fg={theme.accent2}>q</span>
          <span fg={theme.muted}> quit</span>
        </text>
      </box>

      {props.loadErrors.length > 0 && (
        <text fg={theme.warn}>skipped: {props.loadErrors.join("; ")}</text>
      )}
    </box>
  )
}
