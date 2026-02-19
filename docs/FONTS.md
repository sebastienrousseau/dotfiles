# Font configuration

Learn about font setup, rendering, and the fonts included with these dotfiles.

## Recommended fonts

### Primary: JetBrains Mono Nerd Font

Your default font is JetBrains Mono with Nerd Font patches.

Features:
- Designed for code readability
- Ligature support
- Powerline/Nerd Font glyphs
- Clear distinction between similar characters (0/O, 1/l/I)

### Alternatives

| Font | Style | Best for |
|------|-------|----------|
| Fira Code | Modern | People who enjoy ligatures |
| Cascadia Code | Microsoft | People who use VS Code |
| Hack | Classic | People who prefer a classic look |
| Source Code Pro | Adobe | Clean aesthetic |
| Iosevka | Narrow | Small screens |

## Installation

### macOS (Homebrew)

```bash
# Install via Homebrew
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# Or use dot CLI
dot fonts install
```

### Linux (manual)

```bash
# Download from Nerd Fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip

# Extract to fonts directory
unzip JetBrainsMono.zip -d ~/.local/share/fonts/

# Update font cache
fc-cache -fv
```

### Using the font patcher

To patch your own fonts with Nerd Font glyphs:

```bash
# Use the included script
~/.dotfiles/scripts/fonts/patch-fonts.sh /path/to/font.ttf
```

## Font rendering

### Sample characters

```
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
!@#$%^&*()_+-=[]{}|;':",.<>?/

Ligatures: -> => == != <= >= && || :: ...
Powerline:
Nerd Font:
```

### Ambiguous characters

The font configuration provides clear distinction between:

```
0 vs O (zero vs capital O)
1 vs l vs I (one vs lowercase L vs capital I)
` vs ' (backtick vs single quote)
" vs " (straight vs curly quotes)
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

1. Verify font is installed: `fc-list | grep JetBrains`
2. Restart terminal application
3. Check terminal font settings

### Nerd Font icons missing

1. Verify you are using a Nerd Font variant
2. Confirm the terminal supports the Unicode range
3. Try a different Nerd Font

### Ligatures not working

1. Enable ligatures in terminal settings
2. Some terminals do not support ligatures (for example, Terminal.app)
3. Try Ghostty, WezTerm, or Kitty
