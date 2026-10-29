# pnpm Aliases

Manage pnpm aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `pnpm.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `node`. Every definition below exists only when `pnpm` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `pna` | `pnpm add` | Add a dependency to the project. |
| `pnad` | `pnpm add --save-dev` | Add a dev dependency to the project. |
| `pnap` | `pnpm add --save-peer` | Add a peer dependency to the project. |
| `pnau` | `pnpm audit` | Audit the project. |
| `pnb` | `pnpm run build` | Build the project. |
| `pnc` | `pnpm create` | Create a new project. |
| `pnd` | `pnpm run dev` | Run the project in dev mode. |
| `pndoc` | `pnpm run doc` | Generate the project documentation. |
| `pnga` | `pnpm add --global` | Add a global dependency. |
| `pngls` | `pnpm list --global` | List all global dependencies. |
| `pngrm` | `pnpm remove --global` | Remove a global dependency. |
| `pngu` | `pnpm update --global` | Update a global dependency. |
| `pnh` | `pnpm help` | Show the help. |
| `pni` | `pnpm init` | Initialize a new project. |
| `pnin` | `pnpm install` | Install the project dependencies. |
| `pnln` | `pnpm run lint` | Lint the project. |
| `pnls` | `pnpm list` | List all dependencies. |
| `pnout` | `pnpm outdated` | Check for outdated dependencies. |
| `pnp` | `pnpm` | Shortcut to pnpm. |
| `pnpub` | `pnpm publish` | Publish the project. |
| `pnrm` | `pnpm remove` | Remove a dependency from the project. |
| `pnrun` | `pnpm run` | Run a script from the project. |
| `pns` | `pnpm run serve` | Run the project in serve mode. |
| `pnst` | `pnpm start` | Start the project. |
| `pnsv` | `pnpm server` | Run the project in server mode. |
| `pnt` | `pnpm test` | Test the project. |
| `pntc` | `pnpm test --coverage` | Test the project with coverage. |
| `pnui` | `pnpm update --interactive` | Update a dependency interactively. |
| `pnuil` | `pnpm update --interactive --latest` | Update a dependency interactively to the latest version. |
| `pnun` | `pnpm uninstall` | Uninstall the project dependencies. |
| `pnup` | `pnpm update` | Update a dependency. |
| `pnwhy` | `pnpm why` | Check why a dependency is installed. |
| `pnx` | `pnpx` | Shortcut to pnpx. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
