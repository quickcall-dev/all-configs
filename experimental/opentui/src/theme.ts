export const theme = {
  // warm paper — light, low-glare, distinct from the default dark TUI.
  // (One step off the renderer clear color so cells paint explicitly.)
  bg: "#FBF8F3",
  panel: "#FFFFFF",
  border: "#E2DCD2",
  faint: "#C9C2B6",
  highlight: "#F3EDE3", // cursor row — sand
  text: "#2A251E", // espresso ink
  muted: "#71695E",
  accent: "#047857", // emerald — selection, primary
  accent2: "#0F766E", // teal — keys, spinner, secondary
  ok: "#15803D",
  warn: "#A16207",
  err: "#B91C1C",
} as const

export type Tone = keyof typeof theme

/**
 * Forest-to-gold gradient across the wordmark's glyphs: deep emerald →
 * green → lime → gold. 700–800 shades so the lettering holds on paper.
 */
export const GRADIENT = [
  "#065F46",
  "#046E50",
  "#047857",
  "#059669",
  "#0DA271",
  "#10B981",
  "#16A34A",
  "#4D7C0F",
  "#65A30D",
  "#CA8A04",
] as const
