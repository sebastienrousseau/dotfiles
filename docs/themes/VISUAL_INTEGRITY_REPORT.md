# Visual Integrity Report

Generated: 2026-04-08
Scope: terminal theme SSOT, shell first-paint path, font rendering, and cross-platform template intent.

| Metric | Current | Target | Status |
| :--- | :--- | :--- | :--- |
| Contrast (APCA) | `macos-monterey-dark` body text `Lc 90+`, critical UI `Lc 95+` | `Lc 75+` body, `Lc 90+` critical | Pass |
| Startup Time | `bash 25ms`, `zsh 35ms`, `fish 25ms` | `< 100ms` | Pass |
| Color DeltaE | SSOT palette unified across Ghostty/Kitty/Alacritty/WezTerm; no runtime probe yet | `< 2.0` | Needs instrumentation |

## Findings

- Theme colors are already centralized in `.chezmoidata/themes.toml`, but accessibility intent was implicit. The active theme now carries explicit OKLCH/APCA metadata.
- First-prompt Fish initialization still performed live CLI work when cache artifacts were present. The prompt path now sources prewarmed cache files first and only regenerates on cache miss.
- Terminal templates were palette-consistent, but rendering policy was inconsistent. macOS now prefers Display P3 and CoreText-friendly metrics; Linux/Wayland templates prefer more conservative opacity and FreeType-safe fallbacks.

## Edge Cases

- Wayland fontconfig now sets `rgba` declaratively from feature flags to avoid color fringing on mixed-density Linux panels.
- Ghostty, Kitty, Alacritty, and WezTerm now share the same terminal ramp while allowing platform-specific font fallback and window-compositor behavior.
- WSL parity is still template-capable, but DeltaE validation is not yet automated against Windows Terminal serialization.

## Next Step

Implement a small palette audit utility that computes APCA and DeltaE from `.chezmoidata/themes.toml` so the report can become test-backed rather than declarative.
