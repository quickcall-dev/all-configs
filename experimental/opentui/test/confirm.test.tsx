import { expect, test } from "bun:test"
import { testRender } from "@opentui/react/test-utils"
import { ConfirmDialog } from "/Users/sagar/all-configs/experimental/opentui/src/screens/ConfirmDialog"

const mod = {
  name: "aliases", description: "", kind: "config", platforms: ["mac"],
  status: "installed", can_uninstall: false, uninstall_packages: [],
} as any

test("confirm dialog renders", async () => {
  const setup = await testRender(
    <ConfirmDialog plan={{ action: "install", run: [mod], notes: [] }} onResolve={() => {}} />,
    { width: 80, height: 24 },
  )
  try {
    await setup.renderOnce()
    expect(setup.captureCharFrame()).toContain("Install")
  } finally {
    setup.renderer.destroy()
  }
}, { timeout: 5000 })
