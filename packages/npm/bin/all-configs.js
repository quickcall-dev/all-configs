#!/usr/bin/env node

const { spawnSync } = require("node:child_process")
const { dirname, join, resolve } = require("node:path")

const platform = process.platform
const arch = process.arch

const arg = process.argv[2]
if (arg === "--version" || arg === "-v" || arg === "version") {
  console.log(`all-configs ${require("../package.json").version}`)
  process.exit(0)
}

const key = `${platform}-${arch}`
const packages = {
  "darwin-arm64": "@quickcall/all-configs-darwin-arm64",
  "darwin-x64": "@quickcall/all-configs-darwin-x64",
  "linux-arm64": "@quickcall/all-configs-linux-arm64",
  "linux-x64": "@quickcall/all-configs-linux-x64",
}

const platformPackage = packages[key]
if (!platformPackage) {
  console.error(`all-configs does not support ${platform}/${arch}`)
  process.exit(1)
}

let packageJson
try {
  packageJson = require.resolve(`${platformPackage}/package.json`)
} catch {
  console.error(`The all-configs binary for ${platform}/${arch} is unavailable.`)
  console.error(`Try reinstalling without omitting optional dependencies:`)
  console.error(`  npm install -g @quickcall/all-configs`)
  process.exit(1)
}

const binary = join(dirname(packageJson), "bin", "all-configs")
const runtimeRoot = resolve(__dirname, "..", "runtime")
const result = spawnSync(binary, process.argv.slice(2), {
  stdio: "inherit",
  env: { ...process.env, ALL_CONFIGS_ROOT: runtimeRoot },
})

if (result.error) {
  console.error(`Failed to start all-configs: ${result.error.message}`)
  process.exit(1)
}

process.exit(result.status ?? 1)
