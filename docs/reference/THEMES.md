# Themes

48 themes. Dark and light variants. WCAG AAA compliant.

Every theme lives in `.chezmoidata/themes.toml` -- the single source of truth for all color definitions across the fleet. Templates read from `{{ .themes.<name> }}` and render terminal colors, UI accents, GTK settings, Neovim colorschemes, and VS Code themes in one pass.

## Quick Start

```bash
dot theme                    # Interactive picker
dot theme catppuccin-mocha   # Switch by name
dot theme toggle             # Toggle dark/light
dot theme list               # List all themes
```

---

## Classic Themes

24 themes from established color scheme projects. Each defines full 16-color terminal palettes, UI accent colors, and application-specific mappings.

### Catppuccin

Four flavors covering the full dark-to-light range. Extended palette includes 26 named colors for GTK CSS generation.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `catppuccin-mocha` | dark | `#89b4fa` | catppuccin |
| `catppuccin-macchiato` | dark | `#8aadf4` | catppuccin |
| `catppuccin-frappe` | dark | `#8caaee` | catppuccin |
| `catppuccin-latte` | light | `#024ad9` | catppuccin |

### Dracula

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `dracula` | dark | `#bd93f9` | dracula |

### Gruvbox

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `gruvbox-dark` | dark | `#83a598` | gruvbox |
| `gruvbox-light` | light | `#026173` | gruvbox |

### Nord

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `nord` | dark | `#81a1c1` | nord |

### Tokyo Night

Four variants: deep night, storm, moonlight, and a full light mode.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `tokyonight-night` | dark | `#7aa2f7` | tokyonight |
| `tokyonight-storm` | dark | `#7aa2f7` | tokyonight |
| `tokyonight-moon` | dark | `#82aaff` | tokyonight |
| `tokyonight-day` | light | `#0453bf` | tokyonight |

### Rose Pine

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `rose-pine` | dark | `#1c5f7a` | rose-pine |
| `rose-pine-moon` | dark | `#0e5f80` | rose-pine |
| `rose-pine-dawn` | light | `#1e5f79` | rose-pine |

### Kanagawa

Three variants inspired by Katsushika Hokusai's ink wash paintings.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `kanagawa-wave` | dark | `#7e9cd8` | kanagawa |
| `kanagawa-dragon` | dark | `#8ba4b0` | kanagawa |
| `kanagawa-lotus` | light | `#3c588a` | kanagawa |

### One

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `onedark` | dark | `#61afef` | one |
| `onelight` | light | `#174fc9` | one |

### Solarized

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `solarized-dark` | dark | `#005aa1` | solarized |
| `solarized-light` | light | `#005aa1` | solarized |

### Everforest

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `everforest-dark` | dark | `#a7c080` | everforest |
| `everforest-light` | light | `#8da101` | everforest |

---

## Wallpaper Themes

24 themes derived from macOS wallpapers and abstract designs. Each dark/light pair matches a wallpaper in `~/Pictures/Wallpapers/`. Terminal palettes are desaturated for dark variants and saturated for light variants, following Apple HIG contrast guidelines.

### Abstract Waves

Deep blue-to-indigo wave bands.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `abstract-waves-dark` | dark | `#4252a2` | abstract |
| `abstract-waves-light` | light | `#4252a2` | abstract |

### Adwaita

Geometric shapes inspired by GNOME's default aesthetic.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `adwaita-dark` | dark | `#58a0a8` | adwaita |
| `adwaita-light` | light | `#3555a5` | adwaita |

### Colourful

Red, maroon, and cyan wave bands with warm-cool contrast.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `colourful-dark` | dark | `#38a0c8` | colourful |
| `colourful-light` | light | `#6444ac` | colourful |

### iMac Blue

Electric blue curves on deep navy.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `imac-blue-dark` | dark | `#0058a8` | imac |
| `imac-blue-light` | light | `#0555b5` | imac |

### macOS Big Sur

Navy sky with coral dunes and aurora accents.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-big-sur-dark` | dark | `#794191` | macos |
| `macos-big-sur-light` | light | `#7c3c9c` | macos |

### macOS Mojave

Night desert with silver dune highlights.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-mojave-dark` | dark | `#425a7a` | macos |
| `macos-mojave-light` | light | `#3a5a82` | macos |

### macOS Monterey

Deep indigo base with violet and magenta accents.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-monterey-dark` | dark | `#6b43a3` | macos |
| `macos-monterey-light` | light | `#6646a6` | macos |

### macOS Sequoia

Indigo to cyan to mint light rays.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-sequoia-dark` | dark | `#48a8c8` | macos |
| `macos-sequoia-light` | light | `#006080` | macos |

### macOS Sonoma

Green and blue rolling hills.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-sonoma-dark` | dark | `#58b078` | macos |
| `macos-sonoma-light` | light | `#096727` | macos |

### macOS Tahoe

Royal blue silk with purple horizon.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-tahoe-dark` | dark | `#3951b1` | macos |
| `macos-tahoe-light` | light | `#3050b8` | macos |

### macOS Ventura

Amber and orange flower petals on dark navy.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `macos-ventura-dark` | dark | `#d89048` | macos |
| `macos-ventura-light` | light | `#914100` | macos |

### Monterey Sierra Blue

Cool slate and steel blue mountain layers.

| Theme | Mode | Accent | Family |
| :--- | :--- | :--- | :--- |
| `monterey-sierra-blue-dark` | dark | `#435b73` | monterey |
| `monterey-sierra-blue-light` | light | `#3a5a82` | monterey |

---

## Theme Data Structure

Each theme in `themes.toml` follows this schema:

```toml
[themes.example-dark]
mode = "dark"           # "dark" or "light"
family = "example"      # Groups related dark/light variants

[themes.example-dark.term]
bg = "#1e1e2e"          # Terminal background
fg = "#cdd6f4"          # Terminal foreground
cursor = "#f5e0dc"      # Cursor color
cursor_text = "#1e1e2e" # Text under cursor
sel_bg = "#383a55"      # Selection background
sel_fg = "#cdd6f4"      # Selection foreground
c0 .. c15               # ANSI colors 0-15

[themes.example-dark.ui]
accent = "#89b4fa"      # Primary accent (borders, highlights)
accent_text = "#000000" # Text on accent backgrounds
error = "#f38ba8"       # Semantic: error
warning = "#f9e2af"     # Semantic: warning
success = "#a6e3a1"     # Semantic: success
info = "#89b4fa"        # Semantic: info
panel = "#181825"       # Panel/sidebar background
border = "#313244"      # Border color

[themes.example-dark.app]
nvim = "catppuccin"              # Neovim colorscheme name
nvim_style = "mocha"             # Neovim variant/style
lualine = "catppuccin"           # Lualine theme
gtk_theme = "Adwaita-dark"       # GTK theme name
gtk_icon = "Papirus-Dark"        # Icon theme
gnome_shell = ""                 # GNOME Shell theme
gnome_gtk = "Adwaita-dark"       # GNOME GTK theme
vscode = "Catppuccin Mocha"      # VS Code active theme
vscode_dark = "Catppuccin Mocha" # VS Code dark preference
vscode_light = "Catppuccin Latte"# VS Code light preference
cat_wallpaper = ""               # Catppuccin wallpaper filename
starship_palette = "catppuccin_mocha" # Starship prompt palette
```

Catppuccin themes include an additional `[themes.<name>.ext]` section with 26 named colors (rosewater through crust) for GTK CSS variable generation.

## Adding a Theme

1. Add a new `[themes.<name>]` block to `.chezmoidata/themes.toml`.
2. Define `mode`, `family`, `term`, `ui`, and `app` sections.
3. Pick accent colors that meet WCAG AAA contrast (7:1) against the background.
4. Run `dot theme <name>` to test. All template-driven configs regenerate automatically.
5. Verify with `chezmoi diff` before applying.
