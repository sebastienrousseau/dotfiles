# Security

Security is never negotiable.

Dotfiles enforces security-first design with complete transparency in all system modifications.

## Security Principles

- **Opt-In Only**: Enable hardening explicitly via `DOTFILES_` environment variables.
- **Local Logging**: All actions log to `~/.local/share/dotfiles.log` with zero telemetry.
- **Transparent Privileges**: Sudo requests occur only for system package managers and expire immediately.

## System Hardening

| Feature | Environment Variable | macOS Implementation | Linux Implementation |
|---|---|---|---|
| Firewall | `DOTFILES_FIREWALL=1` | Activates `socketfilterfw` with Stealth Mode | Configures UFW with restrictive rules |
| Telemetry Blocking | `DOTFILES_TELEMETRY=1` | Disables all Diagnostic plists | Removes `whoopsie` and `apport` |
| DNS-over-HTTPS | `DOTFILES_DOH=1` | Enforces browser-level DoH | Configures `resolvectl` for system DoH |
| Idle Lock | `DOTFILES_LOCK=1` | Enforces screensaver timeout | Sets GNOME/KDE idle-delay |

## Secret Management

Dotfiles employs **age** encryption for all sensitive data.

- **Key Generation**: Run `dot secrets-init` to create your encryption key at `~/.config/chezmoi/key.txt`.
- **Encrypted Storage**: All secrets persist as `.age` encrypted files in the repository.
- **Key Protection**: Never commit private keys to version control.

## Vulnerability Reporting

**DO NOT** open public issues for security vulnerabilities. Report via GitHub Security Advisories or the Security Policy guidelines.
