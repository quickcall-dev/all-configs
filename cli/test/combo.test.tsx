import { expect, test } from "bun:test"
import { testRender } from "@opentui/react/test-utils"
import { MainScreen } from "../src/screens/MainScreen"
import { ConfirmDialog } from "../src/screens/ConfirmDialog"
import type { Module } from "../src/types"

const fixture = (over: Partial<Module> = {}): Module => ({
  name: "tmux", description: "tmux config", kind: "config", platforms: ["mac"],
  status: "installed", can_uninstall: false, uninstall_packages: [], ...over,
})
const noop = () => {}

test("main + confirm dialog combo renders", async () => {
  const setup = await testRender(
    <>
      <MainScreen modules={[fixture(), fixture({ name: "zed" })]} platform="mac"
        selected={new Set()} loadErrors={[]} onToggle={noop} onSetVisible={noop}
        onClearSelection={noop} onInstall={noop} onUninstall={noop} onRescan={noop} onQuit={noop} />
      <ConfirmDialog plan={{ action: "install", run: [fixture()], notes: [] }} onResolve={noop} />
    </>,
    { width: 90, height: 24 },
  )
  try {
    await setup.renderOnce()
    const frame = setup.captureCharFrame()
    expect(frame).toContain("Install")
    expect(frame).toContain("tmux")
  } finally {
    setup.renderer.destroy()
  }
}, { timeout: 8000 })
