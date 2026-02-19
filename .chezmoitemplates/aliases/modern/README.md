# Modern Tooling Aliases

Manage Modern Tooling aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `modern.aliases.sh` and are automatically loaded by `chezmoi`.
They provide modern replacements for legacy Unix tools (Rust-based).

## Aliases

### File Listing (eza)
If `eza` is installed (replacing `ls`):
- `ls` - List files (`eza --icons`)
- `ll` - Long list (`eza -alF`)
- `la` - List all (`eza -a`)
- `lt` - List tree (`eza --tree`)

*(Falls back to standard `ls` if `eza` is missing)*

### File Content (bat)
If `bat` is installed (replacing `cat`):
- `cat` - Display file content with syntax highlighting

### Searching (rg)
If `rg` is installed (replacing `grep`):
- `grep` - Search with Ripgrep

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
