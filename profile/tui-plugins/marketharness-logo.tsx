// @ts-nocheck
/** @jsxImportSource @opentui/solid */
import type { TuiPlugin } from "@opencode-ai/plugin/tui"
import { useTerminalDimensions } from "@opentui/solid"
import { createMemo } from "solid-js"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

// marketharness home-screen logo for the OpenCode V1 (1.x) TUI.
// V1 exposes a `home_logo` slot that V2 removed, so the V1 line gets a real
// home-screen replacement. Three tiers, chunky rounded wordmark in the
// OpenCode wordmark style:
//   - full:    82-col x 7-row "marketharness" block art  (width >= 85 && height >= 14)
//   - medium:  62-col x 3-row "marketharness" wordmark  (width >= 65 && height >= 10)
//   - compact: single "◈ marketharness" line            (anything smaller)
//
// EDITABILITY: the art itself lives in logo.json NEXT TO this file (rendered
// to ~/.config/marketharness/tui-plugins/logo.json by install.sh).
// Edit logo.json — rows, colors, split column — and restart the TUI; no TSX
// change needed. This file only holds the render logic and a hardcoded copy
// of the default art used when logo.json is missing or unparseable, so a
// broken logo.json can never break the TUI.

const id = "marketharness-logo"

// --- Default art (fallback only — the editable copy is logo.json) ----------
// "market" in teal, "harness" in emerald: the full tier is two-tone split at
// the gap column right after the t of "market"; the medium/compact tiers are
// single-tone.
const DEFAULT_WORD_A = "#2dd4bf"
const DEFAULT_WORD_B = "#34d399"
const DEFAULT_SPLIT = 40
const DEFAULT_FULL = [
  "                                                                                  ",
  "                       ██            ██  ██                                       ",
  "▄████████▄ ▄███▄ ▄███▄ ██  ██ ▄███▄ ████ ████▄ ▄███▄ ▄███▄ ▄███▄ ▄███▄ ▄███▄ ▄███▄",
  "██  ██  ██    ██ ██ ██ ██ ██  ██ ██  ██  ██ ██    ██ ██ ██ ██ ██ ██ ██ ██    ██   ",
  "██  ██  ██ █████ ██    ████   █████  ██  ██ ██ █████ ██    ██ ██ █████ █████ █████",
  "██  ██  ██ ██ ██ ██    ██ ██  ██     ██  ██ ██ ██ ██ ██    ██ ██ ██       ██    ██",
  "██  ██  ██ ▀███▀ ██    ██  ██ ▀███▀  ██  ██ ██ ▀███▀ ██    ██ ██ ▀███▀ ▀███▀ ▀███▀",
]
const DEFAULT_MEDIUM = [
  "◈                ▀          ▀  ▀                              ",
  "  █▀█▀█ █▀▄▄ █▀▄ █ ▄█ █▀▀▀ ███ ███ █▀▄▄ █▀▄ ███ █▀▀▀ █▀▀▀ █▀▀▀",
  "  █ █ █ ▄▄██ █   █▀█  ██▄   █  █ █ ▄▄██ █   █ █ ██▄  ▄▄▄█ ▄▄▄█",
]
const DEFAULT_COMPACT = "◈ marketharness"

// --- logo.json loading (best effort, per tier) -----------------------------
// Resolved NEXT TO this plugin file: the V1 TSX loader runs the plugin under
// Bun, where import.meta.dir is the file's directory; the file-URL form is
// kept as a fallback for loaders that only implement import.meta.url.
const pluginDir = () => {
  try {
    const meta = /** @type {any} */ (import.meta)
    if (typeof meta.dir === "string" && meta.dir) return meta.dir
    if (typeof meta.url === "string" && meta.url.startsWith("file:")) {
      return fileURLToPath(new URL(".", meta.url))
    }
  } catch {
    /* fall through */
  }
  return null
}

// Rows must all carry the same column count or the centered rows drift
// apart: pad short rows to the widest one instead of trusting the file.
const normalizeRows = (rows) => {
  if (!Array.isArray(rows) || rows.length === 0) return null
  if (!rows.every((r) => typeof r === "string")) return null
  const w = Math.max(...rows.map((r) => r.length))
  return rows.map((r) => r.padEnd(w, " "))
}

const loadLogoJson = () => {
  const dir = pluginDir()
  if (!dir) return null
  try {
    const raw = readFileSync(join(dir, "logo.json"), "utf8")
    const data = JSON.parse(raw)
    const full = normalizeRows(data.full)
    const medium = normalizeRows(data.medium)
    const compact =
      typeof data.compact === "string" && data.compact.trim() ? data.compact : null
    const colors =
      data.colors && typeof data.colors === "object" ? data.colors : {}
    const splitAt =
      Number.isInteger(data.splitAt) && data.splitAt > 0 ? data.splitAt : null
    if (!full && !medium && !compact) return null
    return { full, medium, compact, colors, splitAt }
  } catch {
    return null
  }
}

// Loaded once per TUI setup (the plugin factory below runs once per setup),
// so a restart picks up logo.json edits without any watcher machinery.
const art = (() => {
  const fromJson = loadLogoJson()
  const fullFromJson = fromJson?.full ?? null
  return {
    full: fullFromJson ?? DEFAULT_FULL,
    medium: fromJson?.medium ?? DEFAULT_MEDIUM,
    compact: fromJson?.compact ?? DEFAULT_COMPACT,
    wordA: fromJson?.colors?.wordA ?? DEFAULT_WORD_A,
    wordB: fromJson?.colors?.wordB ?? DEFAULT_WORD_B,
    // Two-tone only when the JSON opts in with splitAt (the built-in
    // default art always splits); otherwise the tier renders single-tone.
    splitAt: fullFromJson ? fromJson.splitAt : DEFAULT_SPLIT,
  }
})()

// --- Rendering --------------------------------------------------------------
// Each line becomes a row of same-color <text> segments. Segment widths are
// derived from the fixed-width grid, so columns always stay aligned.
const twoToneSegments = (line, splitAt, wordA, wordB) => {
  const cut = Math.min(Math.max(splitAt, 0), line.length)
  if (cut === 0) return [{ text: line, color: wordB }]
  if (cut === line.length) return [{ text: line, color: wordA }]
  return [
    { text: line.slice(0, cut), color: wordA },
    { text: line.slice(cut), color: wordB },
  ]
}

const fullLines = art.splitAt
  ? art.full.map((line) => twoToneSegments(line, art.splitAt, art.wordA, art.wordB))
  : art.full.map((line) => [{ text: line, color: art.wordA }])

const plainSegments = (line) => [{ text: line, color: art.wordA }]
const mediumLines = art.medium.map(plainSegments)
const compactLines = [plainSegments(art.compact)]

const Logo = () => {
  const dim = useTerminalDimensions()
  const lines = createMemo(() => {
    const term = dim()
    if (term.width >= 85 && term.height >= 14) return fullLines
    if (term.width >= 65 && term.height >= 10) return mediumLines
    return compactLines
  })

  return (
    <box flexDirection="column" alignItems="center">
      {lines().map((line) => (
        <box flexDirection="row">
          {line.map((segment) => (
            <text fg={segment.color}>{segment.text}</text>
          ))}
        </box>
      ))}
    </box>
  )
}

const tui: TuiPlugin = async (api) => {
  api.slots.register({
    id,
    order: 100,
    slots: {
      home_logo() {
        return <Logo />
      },
    },
  })
}

const plugin = { id, tui }
export default plugin
