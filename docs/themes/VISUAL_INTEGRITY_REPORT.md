---
render_with_liquid: false
---

# Visual Integrity Report

Generated: 2026-09-20
Scope: terminal theme SSOT, shell first-paint path, font rendering, and cross-platform template intent.

| Metric | Current | Target | Status |
| :--- | :--- | :--- | :--- |
| Body text contrast | Catalog minimum `14.950:1` | WCAG `>= 7:1` | Pass |
| Semantic text contrast | Catalog minimum `7.567:1` | WCAG `>= 7:1` | Pass |
| Focus indicator contrast | Catalog minimum `5.758:1` | WCAG non-text `>= 3:1` | Pass |
| xterm-256 ANSI contrast | Catalog minimum `4.836:1` after quantization | `>= 4.5:1` | Pass |
| Wallpaper support separation | Catalog minimum `DeltaE 18.041` | `DeltaE >= 18` | Pass |
| Color-vision semantic separation | Worst protan/deutan/tritan result `DeltaE 9.596` | `DeltaE >= 8` | Pass |
| Startup Time | `bash 25ms`, `zsh 35ms`, `fish 25ms` | `< 100ms` | Pass |
| Runtime color parity | SSOT unified across Ghostty/Kitty/Alacritty/WezTerm/Foot; no framebuffer probe yet | `DeltaE < 2` | Needs instrumentation |

## Findings

- `scripts/theme/audit-palettes.py` derives a deterministic, versioned JSON report from the complete catalog and fails closed on contract violations.
- Status roles use mode-specific semantic colors rather than arbitrary wallpaper clusters; wallpaper identity remains in terminal, accent, support, and session colors.
- Truecolor and xterm-256 are measured independently so quantization cannot silently reduce a compliant source color below the fallback floor.
- First-prompt Fish initialization still performed live CLI work when cache artifacts were present. The prompt path now sources prewarmed cache files first and only regenerates on cache miss.
- Terminal templates were palette-consistent, but rendering policy was inconsistent. macOS now prefers Display P3 and CoreText-friendly metrics; Linux/Wayland templates prefer more conservative opacity and FreeType-safe fallbacks.

## Edge Cases

- Wayland fontconfig now sets `rgba` declaratively from feature flags to avoid color fringing on mixed-density Linux panels.
- Ghostty, Kitty, Alacritty, and WezTerm now share the same terminal ramp while allowing platform-specific font fallback and window-compositor behavior.
- WSL parity is template-capable and its xterm-256 input is audited, but DeltaE validation is not yet automated against Windows Terminal serialization.

## Next Step

Add deterministic golden renders for Ghostty, Kitty, WezTerm, Alacritty, Foot,
and tmux at widths 80/100/120/160 in light, dark, and high-contrast modes.
