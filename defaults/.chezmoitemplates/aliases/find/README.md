# Find Aliases

Manage file search aliases built on `fd`. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `find.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `fd` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `fd` | `fd --color always` | A simple, fast and user-friendly alternative to find Always colorize output by default. |
| `fda` | `fd --absolute-path` | List all files with absolute path. |
| `fdc` | `fd --ignore-case` | List all files with case-insensitive search. |
| `fdd` | `fd --list-details` | List all files with details. |
| `fde` | `fd --extension` | List all files with extension. |
| `fdf` | `fd --follow` | List all files with follow symlinks. |
| `fdh` | `fd --help` | List all files with help. |
| `fdH` | `fd --hidden` | List all files, including hidden files. |
| `fdn` | `fd --glob` | List all files with glob. |
| `fdo` | `fd --owner` | List all files with owner. |
| `fds` | `fd --size` | List all files with size. |
| `fdu` | `fd --exclude` | List all files with exclude. |
| `fdv` | `fd --version` | List all files with version. |
| `fdx` | `fd --exec` | Execute a command for each search result. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
