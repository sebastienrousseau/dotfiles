---
render_with_liquid: false
---
{% raw %}

# Theming Guide

The dotfiles ship a wallpaper-driven theme system that generates terminal color palettes directly from wallpaper images using K-Means clustering in CIELAB color space. One command changes the terminal, editor, window manager, GTK, desktop environment, wallpaper, and browser-facing color mode in under a second.

Themes are not hand-crafted — they are extracted from whatever wallpapers are available on the system.

## How Themes Work

Wallpapers are the source of truth. The system discovers wallpapers from two locations:

1. **System wallpapers** — platform-native (macOS `/System/Library/Desktop Pictures/`, Linux `/usr/share/backgrounds/`)
2. **Custom wallpapers** — user-provided in `~/Pictures/Wallpapers/` (custom overrides system)

`extract-theme.py` extracts dominant colors from each wallpaper using K-Means clustering in CIELAB color space, then generates a full terminal palette (16 ANSI colors, accent, bg/fg, panel, border) with WCAG contrast enforcement.

`rebuild-themes.sh` orchestrates discovery → extraction → assembly into `.chezmoidata/themes.toml`. Themes are cached in `~/.cache/dotfiles/themes/` and only regenerated when wallpapers change.

The `theme` key in `.chezmoidata.toml` controls the active theme. Every template references the active theme's data through `{{ $t := index .themes .theme }}`.

## Switching Themes

### Interactive Picker

```bash
dot theme
```

Opens an fzf picker listing every paired wallpaper theme (themes that have both `-dark` and `-light` variants). Two columns: **WALLPAPER** name and **SOURCE** (System or Custom). The current theme is marked with `✓` and `◀`. Select one and press Enter.

### Direct Switch

```bash
dot theme tahoe-dark
```

Sets the theme immediately. Regenerates configs and reloads running applications.

### Rebuild Themes

```bash
dot theme rebuild           # incremental (uses cache for unchanged wallpapers)
dot theme rebuild --force   # full regeneration
dot theme rebuild --list    # discover wallpapers without rebuilding
```

Discovers wallpapers from system + custom paths, runs K-Means extraction in parallel (4 jobs), caches generated themes in `~/.cache/dotfiles/themes/`, and writes `.chezmoidata/themes.toml`. Custom wallpapers override system wallpapers on name collision.

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

## Command Reference (v0.2.503+)

The full `dot theme` command surface as of v0.2.503:

| Command | Purpose |
|---|---|
| `dot theme` | Interactive picker — fzf with palette preview if available, numbered menu fallback if not |
| `dot theme list` | Print all paired families |
| `dot theme set <NAME> [--force] [--full] [--dry-run]` | Apply a theme by name; idempotent when unchanged |
| `dot theme toggle` | Flip light ↔ dark within the current family |
| `dot theme mode <dark\|light>` | Idempotently force a mode |
| `dot theme family` | Cycle to the next paired family, preserve mode |
| `dot theme random [--mode <dark\|light>]` | Random family; keeps current mode unless `--mode` given |
| `dot theme preview <NAME>` | Apply, wait for ENTER to keep or Ctrl-C to revert |
| `dot theme undo` | Step back one entry in the history stack (toggle-style) |
| `dot theme history` | Show the recently-applied stack (max 20) |
| `dot theme current` | Print the active theme |
| `dot theme status [--json]` | Full dashboard: recorded vs live gsettings/kwriteconfig (JSON output for scripting) |
| `dot theme diff <a> <b>` | Side-by-side field-by-field comparison with colour swatches |
| `dot theme accent [<color\|int>]` | Live-tweak the desktop accent without changing wallpaper/theme |
| `dot theme wallpaper [<path>]` | Set an arbitrary wallpaper without a theme swap |
| `dot theme fit <mode>` | Wallpaper scale mode (`zoom`, `spanned`, `centered`, `scaled`, `stretched`, `wallpaper`, `none`) |
| `dot theme sync` | Match the theme to system dark/light preference (GNOME + KDE) |
| `dot theme ambient <run\|enable\|disable\|status>` | Time-based auto-switch + systemd user timer |
| `dot theme reset` | Restore GNOME defaults (accent/cursor/fonts/shell-theme); wallpaper untouched |
| `dot theme rebuild [--force\|--list]` | Regenerate `themes.toml` from wallpaper library |
| `dot theme help` | Print the built-in usage list |

### Idempotency and `--force`

`dot theme set X` when X is already active is a **40 ms no-op** — no chezmoi apply, no reload chain. Pass `--force` (`-f`) to re-apply anyway (useful after editing config templates without changing the theme name):

```bash
dot theme set Sonoma-dark            # 40 ms if Sonoma-dark is current
dot theme set Sonoma-dark --force    # ~900 ms full re-apply
dot theme set Sonoma-dark --full     # even fuller: full chezmoi apply, not targeted
```

### Ambient auto-switch

```bash
dot theme ambient enable                          # install user timer (hourly + on login)
DOT_THEME_SUNRISE=06:30 DOT_THEME_SUNSET=18:45 \
  dot theme ambient run                           # one-shot with custom times
dot theme ambient status                          # show sunrise/sunset + timer state
```

Persistent state lives at `~/.local/state/dot/theme-ambient.conf` (auto-generated on first `enable`). The systemd timer runs `dot theme ambient run` every hour and 30 s after login, with `Persistent=true` so a suspended machine catches up on missed firings when it wakes.

## Cross-DE Coverage on Linux

`dot theme` detects the running desktop via `$XDG_CURRENT_DESKTOP`, `$DESKTOP_SESSION`, and `pgrep` fallbacks, then routes to the correct handler. Supported:

| DE / Compositor | Color scheme | GTK theme | Icons | Wallpaper | Accent | Cursor | Fonts | Shell theme |
|---|---|---|---|---|---|---|---|---|
| **GNOME 47+** | ✅ gsettings | ✅ | ✅ | ✅ light+dark | ✅ 9-color enum | ✅ | ✅ mono/UI/doc | ✅ User Themes ext |
| **KDE Plasma 5.24+/6** | ✅ plasma-apply-colorscheme + kwriteconfig | ✅ (for GTK apps) | ✅ (+ kdeglobals Icons) | ✅ plasma-apply / qdbus | ✅ hex (Plasma 6.2+) | ✅ XCursorTheme | ✅ font/fixed | n/a |
| **XFCE** | ⚠️ via GTK theme | ✅ xfconf | ✅ | ✅ per-monitor | ⚠️ inherit | ✅ | ✅ FontName/MonospaceFontName | n/a |
| **Cinnamon/MATE/Budgie/Unity/LXQt** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | (varies) |
| **sway / Hyprland / niri** | ✅ portal | ✅ | ✅ | ✅ swww / hyprctl / DMS | ✅ | ✅ | ✅ | n/a |

Detection order:
1. `$XDG_CURRENT_DESKTOP` (matches specific DEs like `Budgie:GNOME` before the generic `*gnome*`)
2. `$DESKTOP_SESSION`
3. `pgrep -x plasmashell / gnome-shell / xfce4-session / cinnamon / mate-session / sway / Hyprland / niri`
4. `unknown` — falls through to the GNOME/gsettings path (safe defensive)

### Font swaps

Themes can optionally specify per-mode fonts in `themes.toml`:

```toml
[themes.Miami-dark.app]
mono_font = "JetBrainsMono Nerd Font 12"
ui_font = "Cantarell 11"
document_font = "Cantarell 11"
```

Env-var override (lower priority than the theme value):

```bash
DOT_THEME_MONO_FONT="Fira Code 11" DOT_THEME_UI_FONT="Inter 11" dot theme set Sonoma-dark
```

When neither is set, `dot theme` **does not touch** font state — the user's existing font choices are preserved.

### GNOME Shell theme

Populate `gnome_shell` in `[themes.NAME.app]` OR set `DOT_THEME_GNOME_SHELL`, OR — if left empty — `dot theme` auto-matches the GTK theme name when a `/gnome-shell` subdir exists under `/usr/share/themes`, `~/.themes`, or `~/.local/share/themes`. Covers Adwaita-dark, Yaru-dark, WhiteSur-Dark, Fluent-Dark packaged together.

Writing to `org.gnome.shell.extensions.user-theme` is a no-op if the User Themes extension is not installed — safe on any GNOME session.

### Cursor themes

Auto-switch with mode:

- Dark → `Bibata-Modern-Classic`
- Light → `Bibata-Modern-Ice`
- Fallback → `Adwaita`

Override via env: `DOT_THEME_CURSOR_DARK`, `DOT_THEME_CURSOR_LIGHT`.

## Undo, History, Reset

```bash
dot theme random         # try something surprising
dot theme undo           # nope, back to what I had
dot theme undo           # actually the random pick was nice — toggle back
dot theme history        # show recent themes
dot theme reset          # restore GNOME defaults (wallpaper stays)
```

History lives at `~/.local/state/dot/theme-history`, one theme per line, deduped on entry, capped at 20.

## Theme Families

Available themes depend on your system. Run `dot theme list` to see what's discovered. On macOS Sonoma, you'll see ~150+ themes from system wallpapers. Custom wallpapers in `~/Pictures/Wallpapers/` add more.

### Rebuilding themes

When wallpapers change (new system update, new custom wallpapers), regenerate:

```bash
dot theme rebuild          # Regenerate (uses cache for unchanged wallpapers)
dot theme rebuild --force  # Force full regeneration
dot theme rebuild --list   # List discovered wallpapers without rebuilding
```

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
{% endraw %}
