---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# Appendix F: Comparison

`.dotfiles` is the only dotfiles distribution in this comparison
that ships wallpaper-derived WCAG-AAA themes, agent governance,
cryptographic attestation, a self-healing CLI, and fleet apply on
top of a stock chezmoi source tree.

| | This repo | chezmoi | holman/dotfiles | nikitabobko/dotfiles |
|:---|:---:|:---:|:---:|:---:|
| Cross-platform (macOS/Linux/WSL) | ✓ | ✓ | macOS-leaning | macOS only |
| Multi-shell parity (zsh/fish/nu/pwsh) | ✓ | — | bash only | zsh only |
| Wallpaper-driven themes (K-Means) | ✓ | — | — | — |
| AI / MCP integration | ✓ | — | — | — |
| Cryptographic attestation | ✓ | — | — | — |
| Self-healing CLI | ✓ | — | — | — |
| Fleet management | ✓ | — | — | — |
| Encrypted secrets (age/SOPS) | ✓ | ✓ | — | — |
| Build artifact redirection | ✓ | — | — | — |
| Schema-validated config | ✓ | — | — | — |

`chezmoi` is the underlying templating engine. This repo is the
opinionated reference implementation on top of it, and
[plain chezmoi users can adopt it without moving their source tree](../02-tutorials/06-migrate-from-another-manager.md).
