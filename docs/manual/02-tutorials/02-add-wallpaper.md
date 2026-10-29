---
render_with_liquid: false
---

# Tutorial: Add a Wallpaper → Theme

Drop an image. Get a terminal theme whose text colours meet WCAG AAA (7:1) contrast.

## Prerequisites

- Dotfiles installed (see [First Install](01-first-install.md))
- `magick` (ImageMagick) and `python3` available
- Optional: `heif-enc` for creating dynamic HEIC (`brew install libheif`)

## Option A: Drop a Static Image

The simplest path: place a wallpaper in `~/Pictures/Wallpapers/` (or `$DOTFILES_WALLPAPER_DIR`) and rebuild. A file named `<name>-dark.<ext>` or `<name>-light.<ext>` becomes that one variant; a single image without a suffix is themed in both modes, as `<name>-dark` and `<name>-light`.

```sh
cp ~/Downloads/my-wallpaper.jpg ~/Pictures/Wallpapers/mytheme-dark.jpg
cp ~/Downloads/my-wallpaper-light.jpg ~/Pictures/Wallpapers/mytheme-light.jpg

dot theme rebuild
```

The output has this shape (the counts depend on your library and the cache):

```
Discovering wallpapers...
  Found: <system> system, <custom> custom wallpapers (<total> total → <n> light/dark themes)

Generating themes...
  Processing <n> wallpapers (4 parallel jobs)...
  mytheme-dark                             [custom] ✓
  mytheme-light                            [custom] ✓

Results: <n> generated, <n> cached, <n> failed

Assembling themes.toml...
  Written: ~/.dotfiles/defaults/.theme-manifest/themes.toml (<n> themes)

Done. Run 'dot theme list' to see available themes.
```

Switch to the new theme:

```sh
dot theme set mytheme-dark
```

## Option B: Dynamic HEIC (Recommended)

Apple's dynamic HEIC format stores both dark and light variants in a single file with metadata that macOS uses to auto-switch appearance. This is the native format for Apple system wallpapers.

### Create a Dynamic HEIC From a Pair

If you have `mytheme-dark.jpg` + `mytheme-light.jpg`:

```sh
bash ~/.dotfiles/scripts/theme/merge-wallpaper.sh mytheme
```

This:

1. Finds `mytheme-dark` and `mytheme-light` (`.heic`, `.jpg` or `.png`) in the wallpaper directory
2. Converts both to JPEG and encodes them into one `.heic` with `heif-enc` (image 0 = light, image 1 = dark)
3. Injects the `apple_desktop:apr` XMP appearance metadata, if `exiftool` is installed (the step is skipped silently otherwise)
4. Writes `~/Pictures/Wallpapers/mytheme.heic`
5. Removes the two source files

`--dry-run` shows what would be merged without writing anything.

Verify that the file holds two images:

```sh
heif-info ~/Pictures/Wallpapers/mytheme.heic
```

### Rebuild Themes

```sh
dot theme rebuild
```

A multi-frame HEIC is registered as `mytheme-light` (frame 0) and `mytheme-dark` (frame 1), and each frame is themed on its own.

## Option C: Golden Ratio Brightness (Advanced)

For a clear difference between your dark and light variants, a brightness ratio of about 1.6 (close to the golden ratio, 1.618) between the two images works well. This is a rule of thumb for preparing images; the engine does not check it.

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

## Option D: Use System Wallpapers

The wallpapers that ship with the OS (`/System/Library/Desktop Pictures` on macOS, `/usr/share/backgrounds` and `/usr/share/wallpapers` on Linux) are opt-in. Set `DOTFILES_THEME_SYSTEM=1` to include them; a custom wallpaper with the same name wins.

List what would be themed, without rebuilding:

```sh
DOTFILES_THEME_SYSTEM=1 dot theme rebuild --list
```

The listing has a `NAME`, `SOURCE` (`system` or `custom`) and `PATH` column, one row per theme variant, and ends with `Total: <n> wallpapers`.

Rebuild with them, then switch:

```sh
DOTFILES_THEME_SYSTEM=1 dot theme rebuild
dot theme set monterey-dark
```

The engine extracts the wallpaper's dominant colours, generates a palette, and applies it to every surface.

## Verifying the Result

After a switch, check the applied colors:

```sh
# See the current theme's palette
grep -A30 "^\[themes.mytheme-dark\]" ~/.dotfiles/defaults/.theme-manifest/themes.toml
```

Check WCAG compliance. The generator forces every text colour to a 7:1 ratio, and this test checks every theme in `themes.toml`:

```sh
cd ~/.dotfiles
bash tests/unit/theme/test_themes_toml.sh
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

### The Theme Is Missing From the Picker

`dot theme list` and the picker show only families that have both a `-dark` and a `-light` theme. If you added only `mytheme-dark.jpg`, add the light image too, or use a single unsuffixed image, which is themed in both modes.

### Muddy or Flat Palette

The engine runs K-Means three times with fixed seeds and keeps the best clustering. Images that are nearly one solid colour give few distinct clusters, so the palette has little variety. Fix: use a more chromatic source image.

### Wallpaper Doesn't Apply on Linux

On Linux, `dot theme` hands the wallpaper to DMS (Dank Material Shell, `dms ipc`) when `dms` is installed, and then to the first of these it finds:

- **`gsettings`** (GNOME and similar): `picture-uri` and `picture-uri-dark` (a HEIC is converted to PNG first)
- **`swaybg`**
- **`feh`**

If none is found it reports `Wallpaper setter not found (gsettings/swaybg/feh)`.

### The Dark/Light Auto-Switch Isn't Working on macOS

The `apple_desktop:apr` metadata may be missing. Verify:

```sh
magick ~/Pictures/Wallpapers/mytheme.heic -format '%[XMP]' info: | grep apple_desktop
```

If empty, `exiftool` was probably missing when you merged: install it and merge the pair again.

## Summary

You've added a custom wallpaper, generated a WCAG AAA theme from it, and checked that it applied. You can now:

- Add more wallpapers to build a library
- Share your wallpaper directory across hosts (it lives outside the repository, in `~/Pictures/Wallpapers/`)
- Use `dot theme toggle` to swap dark↔light of your current family

## Next

- [Concept: The Theme Engine](../01-concepts/03-theme-engine.md) — deep dive
- [Tutorial: Create a Profile](03-create-profile.md)
- [Cookbook: Theming Recipes](../04-cookbook/01-recipes.md)
