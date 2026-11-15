import { useKeyboard, useTerminalDimensions } from "@opentui/react"
import type { Plan } from "../types"
import { theme } from "../theme"

export function ConfirmDialog(props: { plan: Plan; onResolve(ok: boolean): void }) {
  const { width, height } = useTerminalDimensions()
  const { plan } = props
  const danger = plan.action === "uninstall" || plan.action === "abort"
  const verb = plan.action === "abort" ? "Abort run" : plan.action === "install" ? "Install" : "Uninstall"

  useKeyboard((key) => {
    if (key.name === "y" || key.name === "return") props.onResolve(true)
    else if (key.name === "escape" || key.name === "n") props.onResolve(false)
  })

  const nameW = Math.max(...plan.run.map((m) => m.name.length), 1)

  return (
    <box
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width,
        height,
        backgroundColor: theme.bg,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <box
        style={{
          flexDirection: "column",
          border: true,
          borderStyle: "rounded",
          borderColor: danger ? theme.err : theme.accent,
          backgroundColor: theme.panel,
          padding: 1,
          width: Math.min(70, width - 6),
        }}
        title={` ${verb} `}
      >
        {plan.action === "abort" ? (
          <text fg={theme.text}>
            {"  "}Stop the running step and skip the rest?{"\n"}
            {"  "}The current installer gets killed; finished steps stay as they are.{"\n"}
          </text>
        ) : (
          <text fg={theme.text}>
            {"  "}
            {verb} {plan.run.length} {plan.run.length === 1 ? "module" : "modules"}?{"\n"}
          </text>
        )}

        {plan.run.map((m) => (
          <text key={m.name}>
            <span fg={plan.action === "install" ? theme.ok : theme.err}>  {plan.action === "install" ? "+" : "−"} </span>
            <span fg={theme.text}>{m.name.padEnd(nameW)}</span>
            {plan.action === "uninstall" && (
              <span fg={theme.err}>   removes {m.uninstall_packages.join(" ")}</span>
            )}
            {plan.action === "install" && m.status === "installed" && (
              <span fg={theme.muted}>   re-apply</span>
            )}
          </text>
        ))}

        {plan.notes.map(([title, names]) => (
          <text key={title} fg={theme.warn}>
            {"\n  "}
            {title}
            {"\n  "}
            <span fg={theme.muted}>{names.join(", ")}</span>
          </text>
        ))}

        <text fg={theme.muted}>{"\n  "}y confirm · esc cancel</text>
      </box>
    </box>
  )
}
