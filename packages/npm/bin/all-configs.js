#!/usr/bin/env node
/**
 * all-configs launcher (single-package distribution).
 *
 * The platform binary is NOT bundled in the npm package (that would mean a
 * multi-package setup or a ~240 MB tarball across platforms). Instead the
 * binary is fetched once from the matching GitHub Release
 * (all-configs-tui-<os>-<arch>.gz) and cached:
 *
 *   1. <pkg>/bin/all-configs-tui           (written by postinstall)
 *   2. ~/.cache/all-configs/...            (written on first run, fallback)
 *
 * Env overrides: ALL_CONFIGS_BINARY (explicit binary path),
 * ALL_CONFIGS_ROOT (explicit repo/runtime root).
 */
"use strict"

const { spawnSync } = require("node:child_process")
const { createWriteStream, existsSync, mkdirSync, readFileSync, unlinkSync } = require("node:fs")
const { chmod } = require("node:fs/promises")
const { dirname, join } = require("node:path")
const { tmpdir, homedir, platform, arch } = require("node:os")
const { gunzipSync } = require("node:zlib")
const https = require("node:https")

const VERSION = require("../package.json").version
const REPO = "quickcall-dev/all-configs"
const PKG_BIN = join(__dirname, "all-configs-tui") // next to this launcher
const CACHE_BIN = join(
  process.env.XDG_CACHE_HOME || join(homedir(), ".cache"),
  "all-configs",
  `all-configs-tui-${platform()}-${arch()}`,
)

const arg = process.argv[2]
if (arg === "--version" || arg === "-v" || arg === "version") {
  console.log(`all-configs ${VERSION}`)
  process.exit(0)
}

function fail(message) {
  console.error(`all-configs: ${message}`)
  process.exit(1)
}

function download(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume()
          return resolve(download(res.headers.location))
        }
        if (res.statusCode !== 200) {
          res.resume()
          return reject(new Error(`download failed: HTTP ${res.statusCode} for ${url}`))
        }
        const chunks = []
        res.on("data", (c) => chunks.push(c))
        res.on("end", () => resolve(Buffer.concat(chunks)))
      })
      .on("error", reject)
  })
}

async function fetchBinary(dest) {
  const asset = `all-configs-tui-${platform()}-${arch()}.gz`
  const url = `https://github.com/${REPO}/releases/download/v${VERSION}/${asset}`
  console.error(`all-configs: downloading ${asset} (v${VERSION})…`)
  const gz = await download(url)
  mkdirSync(dirname(dest), { recursive: true })
  const tmp = join(tmpdir(), `all-configs-tui-${process.pid}`)
  require("node:fs").writeFileSync(tmp, gunzipSync(gz))
  require("node:fs").renameSync(tmp, dest)
  await chmod(dest, 0o755)
}

async function executable(path) {
  try {
    await chmod(path, 0o755)
    return true
  } catch {
    return false
  }
}

async function ensureBinary() {
  if (process.env.ALL_CONFIGS_BINARY) return process.env.ALL_CONFIGS_BINARY
  for (const candidate of [PKG_BIN, CACHE_BIN]) {
    if (await executable(candidate)) return candidate
  }
  try {
    await fetchBinary(PKG_BIN)
    return PKG_BIN
  } catch (err) {
    // package dir may be read-only — fall back to the user cache
    await fetchBinary(CACHE_BIN)
    return CACHE_BIN
  }
}

async function main() {
  const binary = await ensureBinary()
  const runtimeRoot = process.env.ALL_CONFIGS_ROOT || join(dirname(__dirname), "runtime")
  const result = spawnSync(binary, process.argv.slice(2), {
    stdio: "inherit",
    env: { ...process.env, ALL_CONFIGS_ROOT: runtimeRoot },
  })
  if (result.error) fail(`failed to start binary: ${result.error.message}`)
  process.exit(result.status ?? 1)
}

// `--ensure-binary`: postinstall hook — pre-fetch so first run is instant.
if (arg === "--ensure-binary") {
  ensureBinary().then(
    (p) => console.log(`all-configs: binary ready at ${p}`),
    (err) => {
      console.error(`all-configs: postinstall download skipped (${err.message})`)
      console.error("all-configs: the binary will be downloaded on first run.")
      process.exit(0) // never fail an install over a download hiccup
    },
  )
} else {
  main().catch((err) => fail(err.message))
}
