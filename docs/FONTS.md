# Font configuration

How fonts are set up, rendered, and installed in these dotfiles.

## Recommended fonts

### Primary: JetBrains Mono Nerd Font

The default font is JetBrains Mono with Nerd Font patches. It's designed for code readability, supports ligatures, includes Powerline/Nerd Font glyphs, and clearly distinguishes similar characters (`0`/`O`, `1`/`l`/`I`).

### Alternatives

| Font | Style | Best for |
|------|-------|----------|
| Fira Code | Modern | Ligature fans |
| Cascadia Code | Microsoft | VS Code users |
| Hack | Classic | Traditional monospace look |
| Source Code Pro | Adobe | Clean aesthetic |
| Iosevka | Narrow | Small screens |

## Installation

### macOS (Homebrew)

```bash
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# Or use the dot CLI
dot fonts install
```

### Linux (manual)

```bash
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.local/share/fonts/
fc-cache -fv
```

### Patching your own fonts

To patch a custom font with Nerd Font glyphs:

```bash
~/.dotfiles/scripts/fonts/patch-fonts.sh /path/to/font.ttf
```

## Terminal configuration

### Ghostty

```
font-family = JetBrains Mono Nerd Font
font-size = 14
```

### WezTerm

```lua
config.font = wezterm.font("JetBrains Mono Nerd Font")
config.font_size = 14.0
```

### Alacritty

```yaml
font:
  normal:
    family: JetBrains Mono Nerd Font
  size: 14.0
```

### Kitty

```
font_family JetBrains Mono Nerd Font
font_size 14.0
```

## Font size recommendations

| Display | Size |
|---------|------|
| 13" laptop | 12-13pt |
| 15" laptop | 13-14pt |
| 24" monitor | 14-15pt |
| 27" 4K monitor | 15-16pt |

## Troubleshooting

### Fonts not displaying correctly

1. Verify the font is installed: `fc-list | grep JetBrains`
2. Restart your terminal
3. Double-check the terminal's font settings

### Nerd Font icons missing

1. Make sure you're using a Nerd Font variant (not the plain version)
2. Confirm the terminal supports the required Unicode range
3. Try a different Nerd Font if the issue persists

### Ligatures not working

1. Enable ligatures in your terminal's settings
2. Some terminals don't support ligatures (e.g., `Terminal.app`)
3. Ghostty, WezTerm, and Kitty all handle ligatures well
