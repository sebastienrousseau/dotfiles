# Theming Guide

The dotfiles ship 24 themes (48 variants) with live switching across every managed application. One command changes the terminal, editor, window manager, GTK, desktop environment, wallpaper, and browser-facing color mode in under a second. All themes follow the `macos-NAME-dark/light` naming convention with single-word identifiers.

## How Themes Work

`.chezmoidata/themes.toml` is the single source of truth. It defines terminal palettes, UI accent colors, and per-application mappings for every theme. Chezmoi templates read from this file at apply time.

The `theme` key in `.chezmoidata.toml` controls the active theme. Every template references the active theme's data through `{{ $t := index .themes .theme }}`, then uses `$t.term.bg`, `$t.ui.accent`, `$t.app.nvim`, and so on.

## Switching Themes

### Interactive Picker

```bash
dot theme
```

Opens an fzf picker listing all themes from `themes.toml`. Themes with matching wallpapers show a `[W]` marker. Select one and press Enter.

### Direct Switch

```bash
dot theme macos-tahoe-dark
```

Sets the theme immediately. Regenerates configs and reloads running applications.

### Under the Hood: dot-theme-sync

`dot-theme-sync` handles the full switching pipeline:

1. Writes the new theme name into `.chezmoidata.toml` (and `chezmoi.toml` if present).
   If those files drift, `dot-theme-sync` now resynchronizes them before rendering because `chezmoi.toml` `[data]` overrides the source data file.
2. Runs a targeted `chezmoi apply` on theme-dependent config files only -- much faster than a full apply.
3. Signals running applications to reload and coordinates browser-facing theme state:

```bash
dot-theme-sync                    # Reload current theme
dot-theme-sync macos-wave-light   # Switch to a new theme
dot-theme-sync --full             # Full chezmoi apply instead of targeted
```

## What Changes

Each theme switch touches these applications:

| Application | Mechanism | What Changes |
| :--- | :--- | :--- |
| **Ghostty** | `chezmoi apply` + macOS app-support sync + DBus `reload-config` or runtime signal fallback | Background, foreground, all 16 ANSI colors, cursor |
| **Tmux** | `chezmoi apply` + `source-file` | Status bar colors, pane borders, mode indicators |
| **Niri** | `chezmoi apply` + `load-config-file` IPC | Window borders, focus ring, inactive tint |
| **Desktop (macOS)** | `osascript` + `defaults write` + `killall` | System appearance (Light/Dark), accent color, highlight color; forces SystemUIServer/Dock/cfprefsd refresh |
| **Wallpaper (macOS)** | `osascript` System Events | Desktop wallpaper set across all displays |
| **Wallpaper (Linux)** | `gsettings` / `dms` / `swaybg` / `feh` | HEIC auto-converted to PNG; `picture-uri` and `picture-uri-dark` set separately |
| **Desktop (Linux/GNOME)** | `chezmoi apply` + `gsettings` | Theme name, icon theme, color scheme preference |
| **Safari / Chrome / Edge** | Native browser appearance follows desktop theme | Browser chrome stays aligned when using the default/native browser theme |
| **Firefox** | `chezmoi apply` on `~/.config/firefox/user.js` | Website color scheme preference follows the active dot theme; link that file into a Firefox profile to enforce it |
| **DMS** | `sed -i` on settings.json + IPC | Stock theme mapped to accent family, dark/light mode |
| **Neovim** | `--remote-expr` Lua eval over socket | Colorscheme, style variant, background mode |
| **VS Code** | `chezmoi apply` on `settings.json` | `workbench.colorTheme` value |
| **Alacritty** | `chezmoi apply` | Full color block regeneration |
| **Kitty** | `chezmoi apply` | Full color block regeneration |
| **WezTerm** | `chezmoi apply` | Color scheme in Lua config |

## Dark/Light Toggle

```bash
dot theme toggle
```

Toggles between the dark and light variant of the current theme family. A theme named `macos-tahoe-dark` toggles to `macos-tahoe-light`, and vice versa.

## Theme Families

Every theme has a dark and light variant. All follow the `macos-NAME-dark/light` naming convention:

- **macos-ai** -- magenta-rose aurora
- **macos-bigsur** -- classic Big Sur landscape
- **macos-blue** -- deep blue abstract
- **macos-blush** -- warm blush gradient
- **macos-citrus** -- vibrant citrus tones
- **macos-green** -- natural green landscape
- **macos-gridgreen** -- geometric green grid
- **macos-heatmap** -- fiery orange-red heatmap
- **macos-indigo** -- deep indigo abstract
- **macos-miami** -- warm olive-earth tones
- **macos-mojave** -- Mojave desert landscape
- **macos-monterey** -- Monterey graphic
- **macos-nova** -- warm amber desert
- **macos-orange** -- deep orange gradient
- **macos-pink** -- coral-pink abstract
- **macos-purple** -- rich purple abstract
- **macos-sequoia** -- Sequoia landscape
- **macos-silver** -- neutral silver gradient
- **macos-sonoma** -- Sonoma rolling hills
- **macos-tahoe** -- Tahoe deep blue silk
- **macos-valentine** -- vivid red-crimson
- **macos-ventura** -- Ventura amber petals
- **macos-wave** -- cool cyan-teal wave
- **macos-yellow** -- warm golden yellow

## What works without wallpapers

Theme switching is a two-tier system:

**Core (always works)** — ships in the repo, no setup needed:
- Terminal colors (Ghostty, Alacritty, Kitty, WezTerm, tmux)
- Editor themes (Neovim colorscheme, VS Code)
- macOS dark/light mode and accent color
- Linux GNOME color-scheme, GTK theme, icon theme
- Browser color mode (Safari, Chrome, Firefox)

**Wallpapers (optional)** — user-provided, enhances the theme:
- Desktop wallpaper matched to the active theme
- Requires `~/Pictures/Wallpapers/` with files named `macos-NAME-dark.heic`

If no wallpapers are present, `dot theme` applies all core changes and skips the wallpaper step. No errors, no manual config.

## Wallpapers (optional)

Wallpapers are not shipped in the repo. Each user sources their own and places them in `~/Pictures/Wallpapers/`:

```
macos-tahoe-dark.heic
macos-tahoe-light.heic
```

The naming convention is `macos-NAME-APPEARANCE.heic` (or `.jpg`/`.png`). The theme picker marks themes with matching wallpapers as `[W]`.

### Wallpaper guidelines

- **Resolution**: 6016x6016 recommended (matches Apple's native resolution)
- **Format**: `.heic` preferred on macOS, `.png`/`.jpg` also supported
- **Brightness**: dark/light pairs targeting a golden ratio (1.618) relationship give balanced contrast across displays

### Platform behavior

| Platform | Wallpaper support | Mechanism |
|---|---|---|
| **macOS** | `.heic`, `.jpg`, `.png` | `osascript` (all desktops) |
| **Linux (GNOME)** | `.png`, `.jpg` (`.heic` auto-converted) | `gsettings picture-uri` + `picture-uri-dark` |
| **Linux (Wayland)** | `.png`, `.jpg` (`.heic` auto-converted) | `swaybg`, `feh`, or Niri/DMS IPC |
| **WSL** | Not applicable | No compositor; terminal colors still apply |

On Linux, `.heic` files are automatically converted to `.png` using `magick`, `heif-convert`, or `convert` (whichever is available). The `.png` is cached and only regenerated when the source `.heic` changes.

### Using your OS default wallpapers

If you don't provide custom wallpapers, your OS keeps its current desktop wallpaper. The theme still applies all color changes (terminal, editor, accent, dark/light mode). This is the expected default for most users.

## Build Artifacts

All build caches (Cargo, Go, pip, uv, Zig) are redirected to `/tmp/builds/` via environment variables in `mise.toml` and `cargo/config.toml`. The directory is created on shell init via `fish/conf.d/env.fish`. Build artifacts are cleared on reboot.

## Troubleshooting

### Theme switch did not apply

Run a full apply to force all configs:

```bash
dot-theme-sync --full
```

### Ghostty did not reload

Ghostty reloads via DBus (`com.mitchellh.ghostty` / `reload-config`). If DBus is unavailable, the fallback sends `SIGUSR2` to the main process and also matches the macOS app bundle path when needed. Verify Ghostty is running:

```bash
pgrep -x ghostty
```

On macOS, Ghostty may also read `~/Library/Application Support/com.mitchellh.ghostty/config`. `dot-theme-sync` now mirrors the regenerated XDG config into that location before reloading so the app-support override cannot keep an older palette active.

### Neovim did not change colors

`dot-theme-sync` finds Neovim server sockets at `/tmp/nvim*/0` and `$XDG_RUNTIME_DIR/nvim.*.0`. If Neovim runs with a custom `--listen` path, the auto-discovery misses it. Restart Neovim to pick up the new theme from the regenerated config.

### GTK theme looks wrong

GTK theme names must match installed themes exactly. Catppuccin themes use names like `catppuccin-mocha-blue-standard+default`. Install the matching GTK theme package or fall back to `Adwaita-dark` / `Adwaita`.

### macOS accent or appearance did not update

`dot-theme-sync` applies macOS appearance using `osascript` and accent via:

```bash
defaults write -g AppleAccentColor -int <value>
```

`dot-theme-sync` now kills `cfprefsd`, `SystemUIServer`, `Dock`, and `System Settings` after writing accent/highlight defaults to force an immediate refresh. If the UI still does not update, close and reopen System Settings.

### Browser theme did not change

Safari, Chrome, and Edge are coordinated through the desktop theme, so custom browser themes can override what `dot-theme-sync` is trying to align. Switch those browsers back to their native/default theme if you want them to track macOS or GTK automatically.

Firefox uses the managed file at `~/.config/firefox/user.js`. Link that file into your active Firefox profile as `user.js` if you want `dot-theme-sync` to control website `prefers-color-scheme` behavior:

```bash
ln -sf ~/.config/firefox/user.js ~/.mozilla/firefox/<profile>/user.js
```

### tmux shows old colors

Tmux reloads via `source-file`. If TPM plugins override colors, run:

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

### Checking the active theme

```bash
grep '^theme = ' ~/.dotfiles/.chezmoidata.toml
```

This prints the current theme name. Cross-reference with `dot theme list` for available options.
