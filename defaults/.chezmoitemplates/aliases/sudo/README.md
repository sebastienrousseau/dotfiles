# sudo Aliases

Manage sudo aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `sudo.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category). Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `sudoi` | `sudo -i` | Canonical superuser shell alias. |
| `_` | `sudo`, with a trailing space so the next word is alias-expanded too | Run the rest of the line with `sudo`. |
| `s` | `sudoi` | Only when `DOTFILES_ENABLE_SHORT_SUDO=1`. |
| `su` | `sudo su` | Only when `DOTFILES_ENABLE_SU_ALIAS=1`. |
| `sudo` | `sudoi` | Only when `DOTFILES_ENABLE_SUDO_ALIAS=1`. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
