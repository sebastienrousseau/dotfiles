# Disk Usage Aliases

Manage disk usage aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `du.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category). Every definition below exists only when `du` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `du` | `du -h` | Display the disk usage of the current directory. |
| `du1` | `du -hxd 1 \| sort -h` | File size of files and directories in current directory. |
| `ducks` | `du -cks * .* \| sort -rn \| head -n 10` | Top 10 largest files and directories in current directory. |
| `duh` | `du` | Plain `du`, which the `du` alias turns into `du -h`. |
| `dus` | `du -hs *` | File size human readable output sorted by size. |
| `dusym` | `du * -hsLc` | File size of files and directories in current directory including symlinks. |
| `dut` | `dus` | Same as `dus`. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
