# Update Aliases

Manage Update aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `update.aliases.sh` and are automatically loaded by `chezmoi`.

## Usage

Run `update` to update your system. This uses [Topgrade](https://github.com/topgrade-rs/topgrade) as the primary update tool, which handles:

- System packages (apt, dnf, pacman, brew)
- Language tools (rustup, cargo, npm, pip via uv, gem)
- Runtime managers (mise, fnm)
- Applications (snap, flatpak, VS Code extensions)
- Dotfiles (chezmoi)

### Commands

| Command | Description |
|---------|-------------|
| `update` | Runs Topgrade (primary). Falls back to `upd` if Topgrade is not installed. |
| `upd` | Manual cross-platform update routine (fallback only). |

### Configuration

Topgrade is configured via `~/.config/topgrade/topgrade.toml`. See [topgrade documentation](https://github.com/topgrade-rs/topgrade#configuration) for options.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
