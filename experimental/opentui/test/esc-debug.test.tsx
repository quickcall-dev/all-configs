import { expect, test } from "bun:test"
import { KeyCodes } from "@opentui/core/testing"
import { testRender } from "@opentui/react/test-utils"
import { App } from "../src/App"

async function frameAfter(setup: any, ms = 150) {
  await new Promise((r) => setTimeout(r, ms))
  await setup.renderOnce()
  return setup.captureCharFrame()
}

test("escape clears search text then blurs", async () => {
  const setup = await testRender(<App onQuit={() => {}} />, { width: 100, height: 30 })
  try {
    const start = Date.now()
    let frame = ""
    while (Date.now() - start < 15000) {
      frame = await frameAfter(setup, 200)
      if (frame.includes("aldente")) break
    }
    setup.mockInput.typeText("/")
    await frameAfter(setup)
    setup.mockInput.typeText("zed")
    frame = await frameAfter(setup, 300)
    expect(frame).toContain("zed")

    setup.mockInput.pressKey(KeyCodes.ESCAPE)
    frame = await frameAfter(setup, 300)
    console.log("after esc1 has zed:", frame.includes("/ zed"))
    expect(frame).not.toContain("/ zed")

    setup.mockInput.pressKey(KeyCodes.ESCAPE)
    frame = await frameAfter(setup, 300)
    setup.mockInput.typeText(" ")
    frame = await frameAfter(setup, 300)
    expect(frame).toContain("1 selected")
  } finally {
    setup.renderer.destroy()
  }
}, { timeout: 30000 })
