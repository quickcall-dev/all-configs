import { theme } from "../theme"
import { MiniWordmark } from "./Wordmark"

interface Entry {
  keys: string
  desc: string
}

const GROUPS: Array<{ title: string; entries: Entry[] }> = [
  {
    title: "SEARCH & MOVE",
    entries: [
      { keys: "/", desc: "focus search" },
      { keys: "esc", desc: "step back — text, focus, selection" },
      { keys: "↑/↓ · j/k", desc: "move cursor" },
    ],
  },
  {
    title: "BATCH & ACT",
    entries: [
      { keys: "space · x", desc: "toggle module in the batch" },
      { keys: "a · n · i", desc: "all / none / invert (filtered)" },
      { keys: "enter", desc: "install selection or highlighted" },
      { keys: "u", desc: "uninstall selection" },
    ],
  },
  {
    title: "RUN SCREEN",
    entries: [
      { keys: "esc", desc: "abort (asks first), or back when done" },
      { keys: "ctrl+r", desc: "retry failed steps" },
      { keys: "reply ›", desc: "answers prompts, never logged" },
    ],
  },
  {
    title: "APP",
    entries: [
      { keys: "r", desc: "rescan detection" },
      { keys: "?", desc: "this help" },
      { keys: "q", desc: "quit" },
    ],
  },
]

function Group(props: { title: string; entries: Entry[] }) {
  return (
    <box style={{ flexDirection: "column", width: 56 }}>
      <text fg={theme.faint}>  {props.title}</text>
      <box style={{ height: 1 }} />
      {props.entries.map((e) => (
        <text key={e.keys}>
          <span fg={theme.accent2}>  {e.keys.padEnd(12)}</span>
          <span fg={theme.text}>{e.desc}</span>
        </text>
      ))}
    </box>
  )
}

/** Full-screen help — typography only, no chrome. esc / q / ? returns. */
export function HelpView() {
  return (
    <box
      style={{
        width: "100%",
        height: "100%",
        flexDirection: "column",
        backgroundColor: theme.bg,
        paddingLeft: 2,
        paddingTop: 1,
      }}
    >
      <MiniWordmark />
      <box style={{ height: 2 }} />
      <box style={{ flexDirection: "row" }}>
        <Group {...GROUPS[0]} />
        <Group {...GROUPS[1]} />
      </box>
      <box style={{ height: 2 }} />
      <box style={{ flexDirection: "row" }}>
        <Group {...GROUPS[2]} />
        <Group {...GROUPS[3]} />
      </box>
      <box style={{ flexGrow: 1 }} />
      <text fg={theme.muted}>  esc · q · ?    back to the modules</text>
      <box style={{ height: 1 }} />
    </box>
  )
}
