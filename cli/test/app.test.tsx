import { expect, test } from "bun:test"
import { testRender } from "@opentui/react/test-utils"
import { feedLines, makeLineBuffer } from "../src/bridge"
import { MainScreen, visibleModules } from "../src/screens/MainScreen"
import type { Module } from "../src/types"

const fixture = (over: Partial<Module> = {}): Module => ({
  name: "tmux",
  description: "tmux config",
  kind: "config",
  platforms: ["mac", "linux"],
  status: "installed",
  can_uninstall: false,
  uninstall_packages: [],
  ...over,
})

test("visibleModules filters by name, kind and status", () => {
  const mods = [
    fixture(),
    fixture({ name: "zed", kind: "app", status: "missing" }),
    fixture({ name: "ghostty", description: "terminal emulator", kind: "app" }),
  ]
  expect(visibleModules(mods, "").length).toBe(3)
  expect(visibleModules(mods, "zed").map((m) => m.name)).toEqual(["zed"])
  expect(visibleModules(mods, "app").map((m) => m.name)).toEqual(["zed", "ghostty"])
  expect(visibleModules(mods, "missing").map((m) => m.name)).toEqual(["zed"])
  expect(visibleModules(mods, "terminal").map((m) => m.name)).toEqual(["ghostty"])
})

test("feedLines collapses carriage-return progress lines", () => {
  const buf = makeLineBuffer()
  let out = feedLines(buf, "installing 10%\rinstalling 20%\n")
  expect(out.lines).toEqual(["installing 20%"])
  expect(out.display).toBe("")
  out = feedLines(buf, "partial prompt:")
  expect(out.lines).toEqual([])
  expect(out.display).toBe("partial prompt:")
  out = feedLines(buf, " more\n")
  expect(out.lines).toEqual(["partial prompt: more"])
})

test("MainScreen renders module rows and summary", async () => {
  const noop = () => {}
  const mods = [fixture(), fixture({ name: "zed", status: "missing", can_uninstall: true, uninstall_packages: ["zed"] })]
  const setup = await testRender(
    <MainScreen
      modules={mods}
      platform="mac"
      selected={new Set(["tmux"])}
      loadErrors={[]}
      onToggle={noop}
      onSetVisible={noop}
      onClearSelection={noop}
      onInstall={noop}
      onUninstall={noop}
      onRescan={noop}
      onQuit={noop}
    />,
    { width: 90, height: 24 },
  )
  try {
    await setup.renderOnce()
    const frame = setup.captureCharFrame()
    expect(frame).toContain("tmux")
    expect(frame).toContain("zed")
    expect(frame).toContain("installed")
    expect(frame).toContain("installed")
  } finally {
    setup.renderer.destroy()
  }
})
