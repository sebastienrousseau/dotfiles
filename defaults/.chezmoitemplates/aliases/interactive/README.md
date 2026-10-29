# Interactive Aliases

Safer, interactive versions of file commands. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `interactive.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category). Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time. Every definition below exists only when `DOTFILES_SAFE_ALIASES=1`.

The default for `DOTFILES_SAFE_ALIASES` is `0`, so none of these is set unless you opt in.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `cp` | `cp -vi` | Copy files and directories interactively (ask before overwrite) with verbose output. |
| `del` | `dot_confirm_destructive "rm -rfvi (del)" && rm -rfvi` | Asks for confirmation, then removes recursively, interactively and verbosely. |
| `ln` | `ln -vi` | Create symbolic links interactively (ask before overwrite) with verbose output. |
| `mv` | `mv -vi` | Move or rename files interactively (ask before overwrite) with verbose output. |
| `rm` | `rm -vi` | Remove files or directories interactively (ask before each removal) with verbose output. |
| `bin` | `dot_confirm_destructive "rm -fr ${HOME}/.Trash" && rm -fr ${HOME}/.Trash` | Asks for confirmation, then empties `~/.Trash`. |
| `diff` | `diff -u` | Compare files in unified format. |
| `mkdir` | `mkdir -pv` | Create a new directory, making parent directories as needed, with verbose output. |

`zap` (confirm, then `rm -vi`) is in the archives aliases, behind the same setting.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
