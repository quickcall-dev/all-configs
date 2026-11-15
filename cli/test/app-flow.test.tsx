import { expect, test } from "bun:test"
import { KeyCodes } from "@opentui/core/testing"
import { testRender } from "@opentui/react/test-utils"
import { App } from "../src/App"

async function frameAfter(setup: any, ms = 150) {
  await new Promise((r) => setTimeout(r, ms))
  await setup.renderOnce()
  return setup.captureCharFrame()
}

async function waitFor(setup: any, needle: string, timeout = 15000) {
  const start = Date.now()
  while (Date.now() - start < timeout) {
    const frame = await frameAfter(setup, 200)
    if (frame.includes(needle)) return frame
  }
  throw new Error(`timed out waiting for ${needle}`)
}

test("app: search aliases, enter, confirm dialog appears", async () => {
  const setup = await testRender(<App onQuit={() => {}} />, { width: 100, height: 28 })
  try {
    await waitFor(setup, "aldente") // discovery finished rendering

    setup.mockInput.typeText("/")
    await frameAfter(setup)
    setup.mockInput.typeText("aliases")
    let frame = await frameAfter(setup, 300)
    expect(frame).toContain("aliases")

    setup.mockInput.pressKey(KeyCodes.RETURN) // submit search, blur input
    await frameAfter(setup)
    setup.mockInput.pressKey(KeyCodes.RETURN) // install highlighted
    frame = await frameAfter(setup, 400)
    expect(frame).toContain("Install 1 module")
  } finally {
    setup.renderer.destroy()
  }
}, { timeout: 30000 })

test("app: install aliases end-to-end through the run screen", async () => {
  const setup = await testRender(<App onQuit={() => {}} />, { width: 100, height: 28 })
  try {
    await waitFor(setup, "aldente")
    setup.mockInput.typeText("/")
    await frameAfter(setup)
    setup.mockInput.typeText("aliases")
    await frameAfter(setup, 300)
    setup.mockInput.pressKey(KeyCodes.RETURN)
    await frameAfter(setup)
    setup.mockInput.pressKey(KeyCodes.RETURN)
    await frameAfter(setup, 400)
    setup.mockInput.typeText("y") // confirm
    const frame = await waitFor(setup, "finished successfully", 30000)
    expect(frame).toContain("› install")
    // back to main
    setup.mockInput.pressKey(KeyCodes.ESCAPE)
    await frameAfter(setup, 400)
  } finally {
    setup.renderer.destroy()
  }
}, { timeout: 60000 })
