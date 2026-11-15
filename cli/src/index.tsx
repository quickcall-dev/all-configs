import { createCliRenderer } from "@opentui/core"
import { createRoot } from "@opentui/react"
import { App } from "./App"
import { REPO_ROOT } from "./bridge"
import { theme } from "./theme"
import { VERSION } from "./version"

const arg = process.argv[2]
if (arg === "--version" || arg === "-v" || arg === "version") {
  console.log(`all-configs ${VERSION}`)
  process.exit(0)
}

if (!process.stdin.isTTY || !process.stdout.isTTY) {
  console.error("all-configs TUI (opentui) needs an interactive terminal")
  process.exit(1)
}

const renderer = await createCliRenderer({
  exitOnCtrlC: true,
  // NOTE: OpenTUI paints empty cells with the terminal's default background,
  // so the light theme expects a light terminal profile (the palette in
  // theme.ts assumes paper #FBF8F3).
  backgroundColor: theme.bg,
})

process.chdir(REPO_ROOT)

const root = createRoot(renderer)
root.render(<App onQuit={() => {
  const code = 0
  renderer.destroy()
  process.exit(code)
}} />)
