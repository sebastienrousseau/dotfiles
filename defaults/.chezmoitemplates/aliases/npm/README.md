# npm Aliases

Manage npm aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `npm.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `node`. Every definition below exists only when `npm` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `npa` | `npm audit` | Audit npm packages. |
| `npc` | `npm cache` | Cache npm package. |
| `npi` | `npm install` | Install npm package. |
| `npl` | `npm list` | List npm packages. |
| `npp` | `npm publish` | Publish npm package. |
| `nprm` | `npm uninstall` | Remove npm package. |
| `npr` | `npm run` | Run npm script. |
| `nprw` | `npm run watch` | Run npm script watch. |
| `nps` | `npm start` | Start npm script. |
| `npt` | `npm test` | Test npm script. |
| `npu` | `npm update` | Update npm package. |
| `npexec` | `npm exec` | Exec npm package. |
| `npy` | `npm why` | Why npm package. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
