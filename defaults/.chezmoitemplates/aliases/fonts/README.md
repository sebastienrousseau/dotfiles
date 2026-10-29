# Font Aliases

Aliases for listing installed fonts. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `fonts.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `list-fonts` | `fc-list : family \| sort \| uniq` | List installed fonts (if fc-list available) |

`update-fonts`, which refreshes the font cache, lives in the system aliases. The terminal font is `terminal_font_family` in `defaults/.chezmoidata.toml` (JetBrainsMono Nerd Font); the fontconfig and kitty configurations fall back to Symbols Nerd Font for icons.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
