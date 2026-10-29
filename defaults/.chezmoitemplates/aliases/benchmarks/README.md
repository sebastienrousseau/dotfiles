# Benchmarks Aliases

Aliases for quick benchmarking with hyperfine. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `benchmarks.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time. Every definition below exists only when `hyperfine` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `bench` | `hyperfine` |  |
| `benchw` | `hyperfine --warmup 3` |  |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
