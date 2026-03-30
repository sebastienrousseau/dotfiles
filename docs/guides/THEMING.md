# Theming Guide

The dotfiles ship 48 themes with live switching across every managed application. One command changes the terminal, editor, window manager, GTK, desktop environment, and browser-facing color mode in under a second.

## How Themes Work

`.chezmoidata/themes.toml` is the single source of truth. It defines terminal palettes, UI accent colors, and per-application mappings for every theme. Chezmoi templates read from this file at apply time.

The `theme` key in `.chezmoidata.toml` controls the active theme. Every template references the active theme's data through `{{ $t := index .themes .theme }}`, then uses `$t.term.bg`, `$t.ui.accent`, `$t.app.nvim`, and so on.

## Switching Themes

### Interactive Picker

```bash
dot theme
```

Opens an interactive menu listing all 48 themes. Select one and press Enter.

### Direct Switch

```bash
dot theme catppuccin-mocha
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
dot-theme-sync catppuccin-latte   # Switch to a new theme
dot-theme-sync --full             # Full chezmoi apply instead of targeted
```

## What Changes

Each theme switch touches these applications:

| Application | Mechanism | What Changes |
| :--- | :--- | :--- |
| **Ghostty** | `chezmoi apply` + macOS app-support sync + DBus `reload-config` or runtime signal fallback | Background, foreground, all 16 ANSI colors, cursor |
| **Tmux** | `chezmoi apply` + `source-file` | Status bar colors, pane borders, mode indicators |
| **Niri** | `chezmoi apply` + `load-config-file` IPC | Window borders, focus ring, inactive tint |
| **Desktop (macOS)** | `osascript` + `defaults write -g AppleAccentColor` | System appearance (Light/Dark), accent color |
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

Toggles between the dark and light variant of the current theme family. A theme named `catppuccin-mocha` (dark) toggles to `catppuccin-latte` (light), and vice versa. The toggle uses the `family` field in `themes.toml` to find the matching counterpart.

## Theme Families

Themes group into families. Each family has at least one dark and one light variant:

- **catppuccin** -- mocha, macchiato, frappe (dark), latte (light)
- **tokyonight** -- night, storm, moon (dark), day (light)
- **rose-pine** -- main, moon (dark), dawn (light)
- **kanagawa** -- wave, dragon (dark), lotus (light)
- **gruvbox** -- dark, light
- **solarized** -- dark, light
- **everforest** -- dark, light
- **one** -- onedark, onelight
- **dracula** -- dark only
- **nord** -- dark only
- **macos** -- big-sur, mojave, monterey, sequoia, sonoma, tahoe, ventura (dark/light pairs)
- **abstract** -- waves (dark/light)
- **adwaita** -- dark/light
- **colourful** -- dark/light
- **imac** -- blue (dark/light)
- **monterey** -- sierra-blue (dark/light)

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

If the UI did not refresh immediately, log out/in once or toggle appearance manually in System Settings.

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
