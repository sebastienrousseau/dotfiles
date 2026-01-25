# Font Configuration

This page documents font setup, rendering, and the fonts included with the dotfiles.

## Recommended Fonts

### Primary: JetBrains Mono Nerd Font

The default font is JetBrains Mono with Nerd Font patches.

Features:
- Designed for code readability
- Ligature support
- Powerline/Nerd Font glyphs
- Clear distinction between similar characters (0/O, 1/l/I)

### Alternatives

| Font | Style | Best For |
|------|-------|----------|
| Fira Code | Modern | Ligature lovers |
| Cascadia Code | Microsoft | VS Code users |
| Hack | Classic | Traditional coders |
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

### Linux (Manual)

```bash
# Download from Nerd Fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip

# Extract to fonts directory
unzip JetBrainsMono.zip -d ~/.local/share/fonts/

# Update font cache
fc-cache -fv
```

### Using the Font Patcher

To patch your own fonts with Nerd Font glyphs:

```bash
# Use the included script
~/.dotfiles/scripts/fonts/patch-fonts.sh /path/to/font.ttf
```

## Font Rendering

### Sample Characters

```
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789
!@#$%^&*()_+-=[]{}|;':",.<>?/

Ligatures: -> => == != <= >= && || :: ...
Powerline:
Nerd Font:
```

### Ambiguous Characters

Fonts are configured to clearly distinguish:

```
0 vs O (zero vs capital O)
1 vs l vs I (one vs lowercase L vs capital I)
` vs ' (backtick vs single quote)
" vs " (straight vs curly quotes)
```

## Terminal Configuration

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

## Font Size Recommendations

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

1. Ensure you're using a Nerd Font variant
2. Check that the terminal supports the Unicode range
3. Try a different Nerd Font

### Ligatures not working

1. Enable ligatures in terminal settings
2. Some terminals don't support ligatures (e.g., Terminal.app)
3. Try Ghostty, WezTerm, or Kitty
