---
render_with_liquid: false
---

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

### With the dot CLI

```bash
dot theme font install                 # JetBrainsMono, FiraCode and Iosevka Nerd Fonts
dot theme font install JetBrainsMono   # one font
```

On macOS this installs the Homebrew casks. On Linux it downloads the Nerd Fonts release archives, checks them against the release's `SHA-256.txt`, unpacks them into `~/.local/share/fonts/` and refreshes the font cache.

### macOS (Homebrew)

```bash
brew install --cask font-jetbrains-mono-nerd-font
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
dot theme font install patch /path/to/font.ttf [output-dir]
```

## Terminal configuration

Ghostty, WezTerm, Alacritty, Kitty, Foot, Fuzzel and VS Code take their font from two keys in `defaults/.chezmoidata.toml`, so you set it once:

```toml
terminal_font_family = "JetBrainsMono Nerd Font"
terminal_font_size = 20
```

Override them per machine in the `[data]` section of `~/.config/chezmoi/chezmoi.toml`, then run `dot apply`. Edit the generated terminal configs only through their templates in `defaults/dot_config/`, or the next apply overwrites your change.

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
