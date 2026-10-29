# Make Aliases

Manage Make aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `make.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `make` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `mk` | `make` |  |
| `mkc` | `make clean` | Make clean. |
| `mkd` | `make doc` | Make doc. |
| `mkf` | `make format` | Make format. |
| `mkh` | `make help` | Make help. |
| `mki` | `make install` | Make install. |
| `mka` | `make all` | Make all. |
| `mkr` | `make run` | Make run. |
| `mkt` | `make test` | Make test. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
