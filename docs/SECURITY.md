# Security

How dotfiles handles security and system modifications.

## Core Principles

- **Opt-In Only** — No hardening applies unless `DOTFILES_*` variables are set to `1`.
- **Local Logging** — All actions log to `~/.local/share/dotfiles.log`. No telemetry.
- **No Hidden Sudo** — Sudo requests only for package managers. Never cached indefinitely.

## Hardening

| Feature | Env Var | Action (macOS) | Action (Linux) |
|---|---|---|---|
| Firewall | `DOTFILES_FIREWALL` | Enables `socketfilterfw` + Stealth Mode | Configures UFW |
| Telemetry | `DOTFILES_TELEMETRY` | Disables Diagnostic plists | Disables `whoopsie`/`apport` |
| DNS-over-HTTPS | `DOTFILES_DOH` | Browser-level settings | Configures `resolvectl` |
| Idle Security | `DOTFILES_LOCK` | Sets screensaver idle time | Sets GNOME/KDE idle-delay |

## Secrets

The dotfiles use **age** for encryption.

- **Initialization**: `dot secrets-init` creates a key at `~/.config/chezmoi/key.txt`.
- **Storage**: Secrets are stored as `.age` encrypted files.
- **Protection**: Private keys aren't committed to the repo.

## SSH Certificates

Short-lived SSH certificates reduce the blast radius of key compromise.

- **Issue**: `dot ssh-cert issue [--ttl 16h] [--principal user]`
- **Status**: `dot ssh-cert status` — checks certificate validity and expiry
- **Revoke**: `dot ssh-cert revoke` — revokes active certificates
- **Backends**: `step-ca` (Smallstep) and local CA key (`ssh-keygen`)
- **Default TTL**: 16 hours (override via `SSH_CERT_TTL` environment variable)
- **CA URL**: Set `SSH_CERT_CA_URL` for `step-ca` integration

## Reporting a Vulnerability

If you discover a security vulnerability, don't open a public issue. Follow the instructions in the Security Policy.
