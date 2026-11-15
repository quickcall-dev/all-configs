import { GRADIENT, theme } from "../theme"

/**
 * One row of ASCII-art glyphs, one gradient color per character.
 * (ASCIIFont color arrays address the font's internal shade layers, not
 * per-character color, so gradient lettering is composed glyph by glyph.
 * Block font metrics, measured on this install: A/C/D/E/F/L/R/S = 8,
 * G/O/T = 9, I = 3 columns, letterspace 1.)
 */
function GlyphRow(props: { text: string; font: "block" | "tiny"; colors: string[]; offset?: number }) {
  const { text, font, colors, offset = 0 } = props
  return (
    <box style={{ flexDirection: "row", gap: 1 }}>
      {text.split("").map((ch, i) => (
        <ascii-font key={i} text={ch} font={font} color={colors[(offset + i) % colors.length]} />
      ))}
    </box>
  )
}

/**
 * The all-configs wordmark: the tiny ASCII face with the aurora gradient
 * running through every glyph. Compact (two rows) so the workspace gets
 * the space; the gradient carries the identity.
 */
export function Wordmark() {
  return (
    <box style={{ height: 2 }}>
      <GlyphRow text="ALL-CONFIGS" font="tiny" colors={[...GRADIENT]} />
    </box>
  )
}

/** Compact single-line variant for secondary screens (run, dialogs). */
export function MiniWordmark() {
  return (
    <box style={{ height: 2 }}>
      <GlyphRow text="all-configs" font="tiny" colors={[...GRADIENT]} />
    </box>
  )
}

/** Faint horizontal rule used to separate the header from the workspace. */
export function Rule(props: { width: number }) {
  return (
    <box style={{ height: 1, width: props.width }}>
      <text fg={theme.faint}>{"─".repeat(Math.max(0, props.width))}</text>
    </box>
  )
}
