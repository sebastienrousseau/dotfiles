# Modern Tooling Aliases

Aliases for modern replacements (eza, bat, zoxide and friends) and listing. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `modern.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

The listing aliases call `dot_*` functions that use `eza` when it is installed and fall back to `ls`; `cat` uses `bat` (or `batcat`) the same way. `grep` is deliberately not aliased to `rg`.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `ls` | `dot_ls` | List with `eza`, or `ls`. |
| `l` | `dot_ls` | Same as `ls`. |
| `ll` | `dot_ll` | Long listing, including dotfiles. |
| `la` | `dot_la` | Listing including dotfiles. |
| `lt` | `dot_lt` | Tree listing. |
| `lr` | `dot_lr` | Recursive long listing. |
| `lra` | `dot_lra` | Recursive long listing, including dotfiles. |
| `lta` | `dot_lta` | Tree listing, including dotfiles. |
| `llm` | `command ls -ltA` |  |
| `lx` | `command ls -la` |  |
| `tree` | `ls -R` | Only when `tree` is not on PATH. |
| `cat` | `dot_cat` | `bat`, `batcat` or `cat`, the first one installed. |
| `zz` | `zoxide` | Only when `zoxide` is on PATH. |
| `zq` | `zoxide query` | Only when `zoxide` is on PATH. |
| `ms` | `mise` | Only when `mise` is on PATH. |
| `msi` | `mise install` | Only when `mise` is on PATH. |
| `msu` | `mise upgrade` | Only when `mise` is on PATH. |
| `msl` | `mise ls` | Only when `mise` is on PATH. |
| `nx` | `nix` | Only when `nix` is on PATH. |
| `nxs` | `nix shell` | Only when `nix` is on PATH. |
| `nxf` | `nix flake` | Only when `nix` is on PATH. |
| `nxu` | `nix flake update` | Only when `nix` is on PATH. |
| `j` | `just` | Only when `just` is on PATH. |
| `jl` | `just --list` | Only when `just` is on PATH. |
| `rgi` | `rg --hidden --glob "!.git"` | Only when `rg` is on PATH. |
| `jqc` | `jq -C` | Only when `jq` is on PATH. |
| `yqv` | `yq eval` | Only when `yq` is on PATH. |
| `de` | `direnv` | Only when `direnv` is on PATH. |
| `dea` | `direnv allow` | Only when `direnv` is on PATH. |
| `ghpr` | `gh pr view --web` | Only when `gh` is on PATH. |
| `ghck` | `gh pr checks` | Only when `gh` is on PATH. |
| `p` | `podman` | Only when `podman` is on PATH. Replaced by `p='pwd'` from `system.aliases.sh`, which loads later in the same layer, unless the system bucket is disabled. |
| `pc` | `podman compose` | Only when `podman` is on PATH. |
| `fz` | `fzf --preview "bat --color=always --style=numbers {} 2>/dev/null \| head -500 \|\| cat {} 2>/dev/null \| head -500"` | Only when `fzf` is on PATH. |
| `zj` | `zellij` | Only when `zellij` is on PATH. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
