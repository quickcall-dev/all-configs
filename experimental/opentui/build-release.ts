export {}

const [target, outfile, libc] = process.argv.slice(2)

if (!target || !outfile) {
  console.error("usage: bun run build-release.ts <target> <outfile> [glibc|musl]")
  process.exit(1)
}

const result = await Bun.build({
  entrypoints: ["./src/index.tsx"],
  compile: {
    target: target as any,
    outfile,
  },
  ...(libc
    ? { define: { "process.env.OPENTUI_LIBC": JSON.stringify(libc) } }
    : {}),
})

if (!result.success) {
  for (const log of result.logs) console.error(log)
  process.exit(1)
}
