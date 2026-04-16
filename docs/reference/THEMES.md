# Themes

Themes are auto-generated from wallpapers. K-Means clustering in CIELAB color space extracts dominant colors. Every theme is WCAG AAA compliant.

There is no fixed theme catalog. The available themes depend on which wallpapers are present on your system. Run `dot theme list` to see what's discovered.

## Source of truth

Wallpapers — not `themes.toml` — are the source of truth. The system discovers wallpapers from two locations:

1. **System wallpapers** — platform-native (macOS `/System/Library/Desktop Pictures/`, Linux `/usr/share/backgrounds/`)
2. **Custom wallpapers** — `~/Pictures/Wallpapers/` (custom overrides system on name collision)

`extract-theme.py` runs K-Means++ in CIELAB on each wallpaper, generates a 16-color terminal palette plus UI/app mappings, and enforces WCAG AAA contrast. `rebuild-themes.sh` orchestrates discovery → parallel extraction → assembly into `.chezmoidata/themes.toml` (cached in `~/.cache/dotfiles/themes/`, regenerated only when wallpapers change).

`.chezmoidata/themes.toml` is a **generated artifact**. Do not edit it directly.

## Quick Start

```bash
dot theme              # Interactive picker (paired wallpaper themes only)
dot theme tahoe-dark   # Switch directly
dot theme toggle       # Swap dark↔light within current family
dot theme rebuild      # Regenerate from current wallpapers
dot theme list         # Show paired themes with System/Custom source
```

## Runtime Apply Behavior

`dot theme` writes the selected theme to `.chezmoidata.toml`, regenerates target configs through chezmoi, then attempts live reloads for running applications.

- **macOS**:
  - Applies system Light/Dark appearance via `osascript` (`System Events`)
  - Applies the wallpaper's derived accent color via `defaults write -g AppleAccentColor` and `AppleHighlightColor`
  - Forces UI refresh via `killall cfprefsd SystemUIServer Dock "System Settings"`
  - Sets desktop wallpaper across all displays via `osascript`
- **Linux**:
  - Applies desktop color scheme through `gsettings`
  - Sets `picture-uri` and `picture-uri-dark` separately
  - Auto-converts HEIC → PNG via `magick`/`heif-convert`/`convert`
  - DMS (Dank Material Shell) integration when present

## Theme Naming

Themes follow the pattern `<wallpaper-name>-<dark|light>`. The wallpaper filename (lowercased, hyphenated) becomes the theme family.

Examples (depend on what's present on your system):

| Wallpaper file | Generated themes |
|:---|:---|
| `~/Pictures/Wallpapers/tahoe.heic` (dynamic HEIC, 2 frames) | `tahoe-dark`, `tahoe-light` |
| `/System/Library/Desktop Pictures/Sonoma.heic` | `sonoma-dark`, `sonoma-light` |
| `/System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic` + `Dome Light.heic` | `dome-dark`, `dome-light` |

Only paired themes (with both dark and light variants) appear in `dot theme` and `dot theme list`.

## Custom Wallpapers — Dynamic HEIC

Custom wallpapers in `~/Pictures/Wallpapers/` ship as Apple-compatible dynamic HEIC files: a single `.heic` containing both light and dark images, tagged with `apple_desktop:apr` XMP metadata. macOS auto-switches the displayed image based on appearance mode.

To merge separate dark + light pairs into a single dynamic HEIC:

```bash
bash scripts/theme/merge-wallpaper.sh           # merge all pairs in ~/Pictures/Wallpapers/
bash scripts/theme/merge-wallpaper.sh tahoe     # merge a specific family
bash scripts/theme/merge-wallpaper.sh --dry-run # preview only
```

## Generated Theme Schema

Each theme block in the generated `themes.toml` follows this schema:

```toml
[themes.example-dark]
mode = "dark"               # "dark" or "light"
family = "example"          # groups dark/light variants
macos_accent = 4            # derived from accent hue (0-6, -1=Graphite)
wallpaper = "/path/to/wallpaper.heic"
source = "custom"           # "custom" or "system"

[themes.example-dark.term]
bg, fg, cursor, cursor_text, sel_bg, sel_fg
c0  .. c15                  # 16 ANSI colors

[themes.example-dark.ui]
accent, accent_text         # white text always 7:1 against accent
error, warning, success, info
panel, border               # contrast-bound (1.03-2.0 for panel, 1.08-3.5 for border)

[themes.example-dark.app]
nvim, nvim_style, lualine
gtk_theme, gtk_icon, gnome_shell, gnome_gtk
vscode, vscode_dark, vscode_light
cat_wallpaper
starship_palette
```

## Adding a Theme

To add a new theme, add a wallpaper — there are no manual TOML edits.

1. Drop a wallpaper into `~/Pictures/Wallpapers/`
2. (Optional) Use `merge-wallpaper.sh` to combine separate dark/light files into a single dynamic HEIC
3. Run `dot theme rebuild` to regenerate `themes.toml` (parallel K-Means extraction, ~1-4s per wallpaper)
4. Run `dot theme <name>` to test
5. Verify with `chezmoi diff` before applying

For best results, wallpapers should be 6016×6016 dynamic HEIC with ~1.6× brightness ratio between dark and light variants (golden ratio). Lower-resolution images are auto-resized; non-paired wallpapers are skipped from the picker.

## See Also

- [Theming Guide](../guides/THEMING.md) — full pipeline documentation
- [Utilities](UTILS.md) — `dot theme` command reference
