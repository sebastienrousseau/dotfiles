# Yarn Aliases

Manage Yarn (JavaScript) aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `yarn.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `node`. Every definition below exists only when `yarn` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `y` | `yarn` |  |
| `ya` | `yarn add` |  |
| `yad` | `yarn add --dev` |  |
| `yga` | `yarn global add` |  |
| `yi` | `yarn install` |  |
| `yin` | `yarn init` |  |
| `yls` | `yarn list` |  |
| `yout` | `yarn outdated` |  |
| `yp` | `yarn pack` |  |
| `yrm` | `yarn remove` |  |
| `yrun` | `yarn run` |  |
| `ys` | `yarn serve` |  |
| `yst` | `yarn start` |  |
| `yt` | `yarn test` |  |
| `ytc` | `yarn test --coverage` |  |
| `yuc` | `yarn global upgrade && yarn cache clean` |  |
| `yui` | `yarn upgrade-interactive` |  |
| `yup` | `yarn upgrade` |  |
| `yv` | `yarn version` |  |
| `yw` | `yarn workspace` |  |
| `yws` | `yarn workspaces` |  |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
