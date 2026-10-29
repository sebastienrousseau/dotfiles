# Clear Aliases

Manage screen-clearing aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `clear.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `validate_dir` | function |  |
| `cdw` | `cd_workspace` | Change to `~/workspace` (the file sets `WORKSPACE_DIR` to it). |
| `c` | `clear_screen` | Clear the screen. |
| `cls` | `clear_list_current` | Clear the screen and list the current directory. |
| `cpl` | `clear_pwd_list` | Clear the screen, print the working directory and list it. |
| `cplt` | `clear_pwd_tree` | Clear the screen, print the working directory and show its tree. |
| `clh` | `clear_history` | Clear the screen and print the command history. |
| `clp` | `print_working_dir` | Print the working directory (it does not clear the screen). Replaced by `clp` from `ai.aliases.sh` (lazy layer) when `claude` is on PATH. |
| `clt` | `clear_print_tree` | Clear the screen and show the directory tree. |

`cl` and `clc` are not clear aliases: `ai.aliases.sh` defines them for Claude Code.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
