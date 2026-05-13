---
render_with_liquid: false
---

# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) that document
significant architectural decisions made in this project.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](ADR-001-ci-cd-pipeline.md) | Multi-stage CI/CD Pipeline Design | Accepted |
| [ADR-002](ADR-002-shell-performance.md) | Shell Performance Optimization Strategy | Accepted |
| [ADR-003](ADR-003-security-first.md) | Security-First Approach | Accepted |
| [ADR-004](ADR-004-cli-architecture.md) | Chezmoi + Custom CLI Wrapper Architecture | Accepted |
| [ADR-005](ADR-005-chezmoi-choice.md) | Chezmoi as Dotfiles Manager | Accepted |
| [ADR-006](ADR-006-shell-selection.md) | Zsh as Default Shell | Accepted |
| [ADR-007](ADR-007-multi-shell-parity.md) | Multi-Shell Parity Strategy | Accepted |
| [ADR-008](ADR-008-alias-system-architecture.md) | Alias System Architecture | Accepted |
| [ADR-009](ADR-009-wallpaper-driven-theming.md) | Wallpaper-Driven Theming Engine | Accepted |
| [ADR-010](ADR-010-starship-transient-prompt.md) | Enable Starship Transient Prompt in Zsh and Fish | Accepted |
| [ADR-011](ADR-011-nushell-tier3-keep.md) | Keep Nushell as Tier-3 Reference with Minimum-Viable Caching | Accepted |

## ADR Format

Each ADR follows this structure:

- **Status**: Proposed, Accepted, Deprecated, Superseded
- **Context**: The situation and forces at play
- **Decision**: The change being made
- **Consequences**: The resulting context after applying the decision

## References

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR Tools](https://github.com/npryce/adr-tools)

