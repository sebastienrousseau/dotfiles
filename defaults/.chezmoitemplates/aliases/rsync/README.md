# rsync Aliases

Manage rsync aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `rsync.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category). Every definition below exists only when `rsync` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `rs` | `rsync -avz` | Archive mode, verbose, compressed. |
| `rsync` | `rs` | Makes plain `rsync` run `rsync -avz`. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
