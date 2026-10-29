# mkdir Aliases

Manage directory creation aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `mkdir.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `mde` | `mkdir -pv "$(date +%Y%m%d)-example"` | Make example directory with current date. |
| `md` | `mkdir -v` | Make directory. |
| `mdd` | `mkdir -pv "$(date +%Y%m%d)" && cd "$(date +%Y%m%d)"` | Make directory with date. |
| `mdn` | `mkdir -pv "$(date +%Y%m%d)-notes"` | Make notes directory with current date. |
| `mdw` | `mkdir -pv "$(date +%Y%m%d)-work"` | Make work directory with current date. |
| `mdt` | `mkdir -pv "$(date +%H%M%S)"` | Make directory with time. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
