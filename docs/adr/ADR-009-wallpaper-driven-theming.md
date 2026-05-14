---
render_with_liquid: false
---

# ADR-009: Wallpaper-Driven Theming Engine

## Status

Accepted

## Date

2026-05-12

## Context

Most dotfiles distributions ship a small fixed palette (Solarized, Gruvbox,
Tokyo Night) chosen once and recycled across every terminal, editor, and
status bar. When the user changes wallpapers — a daily occurrence on macOS
with HEIC dark/light variants and on Linux with `swww`/`hyprpaper` —
terminal chrome stays static, creating visual incoherence between the
chosen wallpaper and the surrounding tooling.

Manual palette switching solves coherence but adds friction: it requires
the user to (a) generate a palette, (b) regenerate config for every tool
(`alacritty.toml`, `kitty.conf`, `wezterm.lua`, neovim themes, …), and
(c) reload each tool. Tools like pywal/wal automate (a) and (b), but
pywal palettes routinely fail WCAG contrast thresholds (especially for
bright wallpapers) and lack support for many of the format files this
project ships.

**Problem:** Reuse the user's chosen wallpaper as the single source of
truth for terminal + status-bar colors, with accessibility guaranteed and
no manual regeneration step.

**Constraints:**

- Output must satisfy **WCAG 2.2 AAA contrast** (≥ 7:1 for normal text,
  ≥ 4.5:1 for large text) — non-negotiable, the dotfiles ship as
  workstation infrastructure.
- Palette extraction must work offline on both macOS (HEIC, dynamic
  wallpapers with embedded dark/light variants) and Linux (PNG/JPEG via
  `swww`, `hyprpaper`, `feh`, GNOME).
- Total time from "user changes wallpaper" → "all terminals retinted"
  must be ≤ 3 seconds (rebuild trigger + write of templated configs).
- Targets include Warp, iTerm2, Alacritty, Ghostty, Kitty, Wezterm,
  Tmux, Neovim (multiple themes), VS Code, Firefox theme JSON, Niri
  borders, Waybar, GTK/Qt (matugen pipeline).

## Decision

Build a self-contained theming engine — `dot theme rebuild` —
implemented in `scripts/theme/` with the following pipeline:

1. **Source detection** — locate the active wallpaper across macOS
   (`defaults read … wallpaper`), GNOME/dconf, KDE, Niri, swww,
   hyprpaper. HEIC dynamic wallpapers decompose into dark and light
   variants; both feed the engine.

2. **Color extraction** — **K-Means clustering in CIELAB** (not RGB).
   CIELAB is perceptually uniform, so distances correlate with the way
   humans see color similarity. 8-cluster K-Means yields a 16-color
   ANSI palette (8 normal + 8 bright) plus 4 accent slots.

3. **Contrast enforcement** — compute WCAG 2.2 contrast against the
   chosen background; nudge each foreground hue along the lightness
   axis until the ratio passes AAA. The nudge stays within the cluster
   to preserve aesthetic intent. If AAA cannot be reached, fall back to
   AA with a logged warning (never silently regress).

4. **Format generation** — emit one canonical TOML palette to
   `.chezmoidata/themes.toml`, then run `chezmoi apply` so every
   theme-aware template (terminals, editors, status bars, browsers)
   regenerates from a single declarative source.

5. **Companion pipelines** — `dot-theme-sync` feeds the same accent
   colors to **matugen** for Material You-style GTK/Qt theming on
   Linux, keeping desktop chrome in lockstep with the terminal.

The whole flow is idempotent (`chezmoi apply` is no-op if nothing
changed), repeatable, and tested under `tests/unit/theme/`.

## Consequences

### Positive

- Single source of truth: change the wallpaper, every tool retints in
  one keystroke.
- Accessibility is structural, not opt-in — every shipped palette
  passes WCAG AAA before it touches a config file.
- No competing "premium" dotfiles distribution (mathiasbynens, holman,
  paulirish, omakub) ships anything similar. The engine is a defining
  differentiator and surfaced in the README hero.
- Reuses chezmoi's templating — no new templating layer to maintain.

### Negative

- K-Means on a 4K wallpaper takes ~500–800 ms; cached after first run,
  but the cold path is non-trivial.
- HEIC handling on Linux requires `libheif` (extra dep on Debian/Ubuntu
  before 24.04).
- Contrast enforcement can produce slightly different palettes from the
  same wallpaper across major OS versions when system color profiles
  differ (mitigated by snapshot tests).

### Risks

- Wallpapers with extreme dynamic range (pure-white backgrounds, deep
  monochrome) may fail to produce an aesthetically pleasing 16-color
  palette even when WCAG AAA is satisfied. Mitigation: maintainer
  curation of a fallback theme set in `.chezmoidata/themes.toml`.
- Future Wayland compositors may not expose a stable wallpaper-detection
  API. The engine isolates source detection in a single module so the
  blast radius of compositor churn is one file.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| pywal/wal | RGB K-Means, no WCAG enforcement, limited target list. |
| matugen alone | Excellent for GTK/Qt; not terminal-aware. We use it *in addition*, not instead. |
| Static curated themes (Tokyo Night et al.) | Loses the "wallpaper coherence" property that motivates the whole project. |
| Hand-roll per-terminal scripts | Doesn't compose with chezmoi; loses the single-source-of-truth invariant. |

## References

- WCAG 2.2 contrast: <https://www.w3.org/TR/WCAG22/#contrast-minimum>
- CIELAB color space: <https://en.wikipedia.org/wiki/CIELAB_color_space>
- `scripts/theme/` — engine source
- `.chezmoidata/themes.toml` — output palette schema
- Issue #873 — captures this ADR alongside `llms.txt`
