# Installer Aliases

Tools for bootstrapping and remote deployment. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `installer.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `dot-install` | `bash "${DOTFILES_DIR:-$HOME/.dotfiles}/install.sh"` | Run `install.sh` from the source checkout. |
| `telegram` | `bash "${DOTFILES_DIR:-$HOME/.dotfiles}/scripts/ops/teleport.sh"` | Run `scripts/ops/teleport.sh` from the source checkout to copy the configuration to a remote host: `telegram user@host`. |
| `dot-teleport` | `telegram` | Runs `telegram`. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
