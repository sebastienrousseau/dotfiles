# Diagnostics Aliases

Tools for health checks and drift repair. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `diagnostics.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `dotdoc` | `bash $HOME/.dotfiles/scripts/diagnostics/doctor.sh` | Run the doctor script from the source checkout. |
| `dot-doctor` | `dotdoc` | Runs `dotdoc`. |
| `dotdoc-full` | `bash $HOME/.dotfiles/scripts/diagnostics/doctor.sh && echo "\n--- Path Info ---" && echo $PATH \| tr ":" "\n" \| glow -` | Run the doctor, then print each `PATH` entry through `glow`. |
| `drift` | `chezmoi verify` | Only when `chezmoi` is on PATH. |
| `dot-drift` | `drift` | Only when `chezmoi` is on PATH. |
| `heal` | `chezmoi apply --verbose` | Auto-Repair (Sync) Only when `chezmoi` is on PATH. |
| `dot-heal` | `heal` | Only when `chezmoi` is on PATH. |
| `capply` | `dot apply` | Only when `chezmoi` is on PATH. |
| `cupdate` | `dot config update` | Only when `chezmoi` is on PATH. |
| `cdiff` | `dot diff` | Only when `chezmoi` is on PATH. |
| `cdrift` | `dot doctor drift` | Only when `chezmoi` is on PATH. |
| `ca` | `chezmoi apply` | Only when `chezmoi` is on PATH. |
| `ce` | `chezmoi edit` | Only when `chezmoi` is on PATH. |
| `cdot` | function | Change to the chezmoi source directory. Only when `chezmoi` is on PATH. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
