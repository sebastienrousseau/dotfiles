# wget Aliases

Manage wget aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `wget.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `wget` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `wg` | `wget` | Plain `wget`, which the `wget` alias turns into `wget -c`. |
| `wgc` | `wg` | Same as `wg` (`wget -c`). |
| `wge` | `wg -e robots=off` | `wget -c -e robots=off`. |
| `wget` | `wget -c` | Resume partial downloads by default. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
