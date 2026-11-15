/**
 * Release version. Release builds bake this in via `bun run build-release.ts`
 * with ALL_CONFIGS_VERSION set (CI sets it from the git tag); dev runs and
 * non-release builds report "dev".
 */
export const VERSION = (process.env.ALL_CONFIGS_VERSION ?? "dev").replace(/^v/, "")
