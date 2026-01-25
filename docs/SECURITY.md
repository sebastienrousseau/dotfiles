# Security

This document provides full transparency into how Dotfiles handles security and modifications.

## Principles

- **Opt-In Only**: No hardening is applied unless the `DOTFILES_` variables are set to `1`.
- **Local Logging**: Actions are logged to `~/.local/share/dotfiles.log`. No telemetry.
- **No Hidden Sudo**: Sudo is only requested for system managers (apt, etc) and never cached indefinitely.

## Hardening

| Feature | Env Var | Action (macOS) | Action (Linux) |
|---|---|---|---|
| Firewall | `DOTFILES_FIREWALL` | Enables `socketfilterfw` + Stealth Mode | Configures UFW |
| Telemetry | `DOTFILES_TELEMETRY` | Disables Diagnostic plists | Disables `whoopsie`/`apport` |
| DNS-over-HTTPS | `DOTFILES_DOH` | Browser-level settings | Configures `resolvectl` |
| Idle Security | `DOTFILES_LOCK` | Sets screensaver idle time | Sets GNOME/KDE idle-delay |

## Secrets

Dotfiles uses **age** for encryption.

- **Initialization**: `dot secrets-init` creates a key at `~/.config/chezmoi/key.txt`.
- **Storage**: Secrets are stored as `.age` encrypted files.
- **Protection**: Private keys are never committed to the repo.

## Report an issue

If you discover a security vulnerability, please do not open a public issue. Follow the instructions in the Security Policy.
