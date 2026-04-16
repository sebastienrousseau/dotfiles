# Tutorial: Add a Wallpaper → Theme

Drop an image. Get a fully-WCAG-AAA terminal theme.

## Prerequisites

- Dotfiles installed (see [First Install](01-first-install.md))
- `magick` (ImageMagick) and `python3` available (installed by default)
- Optional: `heif-enc` for creating dynamic HEIC (`brew install libheif`)

## Option A: Drop a Static Image

The simplest path: place a wallpaper in `~/Pictures/Wallpapers/` and rebuild.

```sh
cp ~/Downloads/my-wallpaper.jpg ~/Pictures/Wallpapers/mytheme-dark.jpg
cp ~/Downloads/my-wallpaper-light.jpg ~/Pictures/Wallpapers/mytheme-light.jpg

dot theme rebuild
```

Expected output:

```
Discovering wallpapers...
  Found: 126 system, 26 custom (152 total)

Generating themes...
  Processing 2 wallpapers (4 parallel jobs)...
  mytheme-dark                             [custom] ✓
  mytheme-light                            [custom] ✓

Results: 2 processed, 150 cached, 0 failed

Assembling themes.toml...
  Written: ~/.dotfiles/.chezmoidata/themes.toml (608 theme sections)

Done. Run 'dot theme list' to see available themes.
```

Switch to the new theme:

```sh
dot theme mytheme-dark
```

## Option B: Dynamic HEIC (Recommended)

Apple's dynamic HEIC format stores both dark and light variants in a single file with metadata that macOS uses to auto-switch appearance. This is the native format for Apple system wallpapers.

### Create a Dynamic HEIC From a Pair

If you have `mytheme-dark.jpg` + `mytheme-light.jpg`:

```sh
bash scripts/theme/merge-wallpaper.sh mytheme
```

This:
1. Resizes both to 6016×6016 (preserving aspect ratio, center-cropped)
2. Encodes both into a single `.heic` via `heif-enc`
3. Injects `apple_desktop:apr` XMP metadata (image 0 = light, image 1 = dark)
4. Writes to `~/Pictures/Wallpapers/mytheme.heic`
5. Removes the two source files

Verify:

```sh
heif-info ~/Pictures/Wallpapers/mytheme.heic
# image: 6016x6016 (id=1), primary    ← light
# image: 6016x6016 (id=4)              ← dark
# metadata:
#   XMP: 2473 bytes                    ← appearance mapping
```

### Rebuild Themes

```sh
dot theme rebuild
# mytheme-light  [custom] ✓
# mytheme-dark   [custom] ✓
```

The engine extracts each frame independently and generates paired themes.

## Option C: Golden Ratio Brightness (Advanced)

For best perceived contrast between your dark and light themes, target a brightness ratio of ~1.6× (the golden ratio, approximately 1.618).

Measure:

```sh
magick ~/Pictures/Wallpapers/mytheme-dark.jpg -resize 1x1\! -format '%[fx:mean]' info:
# 0.30

magick ~/Pictures/Wallpapers/mytheme-light.jpg -resize 1x1\! -format '%[fx:mean]' info:
# 0.48
# Ratio: 0.48 / 0.30 = 1.6   ← ideal
```

Adjust a pair if the ratio is off:

```sh
# Darken light to 0.485 brightness
mod=$(python3 -c "print(int((0.485 / 0.60) * 100))")  # current mean = 0.60
magick input.jpg -modulate ${mod},100,100 output.jpg
```

## Option D: Install System Wallpapers (Already-Available)

macOS ships dozens of wallpapers you can use directly — no download needed.

List what's available:

```sh
dot theme rebuild --list
```

Output:

```
NAME                        SOURCE     PATH
----                        ------     ----
big-sur-graphic-dark        system     /System/Library/Desktop Pictures/.thumbnails/Big Sur Graphic Dark.heic
big-sur-graphic-light       system     /System/Library/Desktop Pictures/.thumbnails/Big Sur Graphic Light.heic
dome-dark                   system     /System/Library/Desktop Pictures/.thumbnails/Dome Dark.heic
dome-light                  system     /System/Library/Desktop Pictures/.thumbnails/Dome Light.heic
sonoma-dark                 system     /System/Library/Desktop Pictures/.thumbnails/Sonoma Dark.heic
...
Total: 152 wallpapers
```

Switch to any system wallpaper:

```sh
dot theme dome-dark
```

The engine extracts Dome Dark's dominant colors, generates a palette, and applies it to every surface.

## Verifying the Result

After a switch, check the applied colors:

```sh
# See the current theme's palette
grep -A30 "^\[themes.mytheme-dark\]" ~/.dotfiles/.chezmoidata/themes.toml
```

Check WCAG compliance (always passes for generated themes):

```sh
bash tests/unit/theme/test_themes_toml.sh
# RESULTS: 11:11:0 (11 tests, 11 passed, 0 failed)
```

Verify the applied wallpaper:

```sh
# macOS
osascript -e 'tell application "System Events" to get picture of every desktop'

# Linux (GNOME)
gsettings get org.gnome.desktop.background picture-uri
gsettings get org.gnome.desktop.background picture-uri-dark
```

## Troubleshooting

### Low Contrast on Both Variants

Your wallpaper pair doesn't have enough brightness difference. The theme will still generate but `dot theme list` may filter it from the picker. Adjust the source images to increase separation (brighter light variant, darker dark variant).

### K-Means Failed to Converge

Rare, but possible with images that are nearly solid color. The engine uses a seeded RNG and 3 runs — if all 3 fail, the output theme is skipped. Fix: use a more chromatic source image.

### Wallpaper Doesn't Apply on Linux

Check your desktop environment:

- **GNOME** — uses `gsettings picture-uri` (HEIC auto-converted to PNG)
- **KDE** — uses `plasma-apply-wallpaperimage`
- **Niri** — uses DMS IPC or `swaybg`
- **i3/sway (no DE)** — falls back to `feh`

If none are detected, set `$WALLPAPER_COMMAND` in `~/.config/dotfiles/config`.

### The Dark/Light Auto-Switch Isn't Working on macOS

The `apple_desktop:apr` metadata may be missing. Verify:

```sh
magick ~/Pictures/Wallpapers/mytheme.heic -format '%[XMP]' info: | grep apple_desktop
```

If empty, re-run `merge-wallpaper.sh` — the XMP injection step may have failed due to missing `exiftool`.

## Summary

You've added a custom wallpaper, generated a WCAG AAA theme from it, and verified cross-surface application. You can now:

- Add more wallpapers to build a library
- Share your wallpaper directory across fleet hosts (it's gitignored by default)
- Use `dot theme toggle` to swap dark↔light of your current family

## Next

- [Concept: The Theme Engine](../01-concepts/03-theme-engine.md) — deep dive
- [Tutorial: Create a Profile](03-create-profile.md)
- [Cookbook: Theming Recipes](../04-cookbook/01-recipes.md)
