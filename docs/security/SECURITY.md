---
render_with_liquid: false
---

# Security

How dotfiles handles security and system modifications.

## Core Principles

- **Opt-In Only** — No hardening applies unless `DOTFILES_*` variables are set to `1`.
- **Local Logging**: `dot` operations (apply, doctor, rollback and related commands) log to `${XDG_STATE_HOME:-~/.local/state}/dot/<domain>/log.jsonl` (log.v1: metadata only, kept 30 days). No telemetry.
- **No Hidden Sudo** — Sudo requests only for package managers. Never cached indefinitely.

## Hardening

| Feature | Env Var | Action (macOS) | Action (Linux) |
|---|---|---|---|
| Firewall | `DOTFILES_FIREWALL` | Enables `socketfilterfw` + Stealth Mode | Configures UFW |
| Telemetry | `DOTFILES_TELEMETRY` | Disables Diagnostic plists | Disables `whoopsie`/`apport` |
| DNS-over-HTTPS | `DOTFILES_DOH` | Browser-level settings | Configures `resolvectl` |
| Idle Security | `DOTFILES_LOCK` | Sets screensaver idle time | Sets GNOME/KDE idle-delay |
| USB Safety | `DOTFILES_USB_SAFETY` | No CLI toggle; points to System Settings | Disables GNOME automount for removable media |

Each row has a `dot security <area> apply` command (`firewall`, `telemetry`,
`dns`, `lock`, `usb`) that changes the system only when its variable is `1`
(`--dry-run` previews), and a matching `show` command.

## Secrets

The dotfiles use **age** for encryption.

- **Initialization**: `dot secret init` creates a key at `~/.config/chezmoi/key.txt`.
- **Storage**: Secrets are stored as `.age` encrypted files.
- **Protection**: Private keys aren't committed to the repo.

## SSH Certificates

Short-lived SSH certificates reduce the blast radius of key compromise.

- **Issue**: `dot secret cert new [--ttl 16h] [--principal user]`
- **Status**: `dot secret cert list` — checks certificate validity and expiry
- **Revoke**: `dot secret cert remove` — revokes active certificates
- **Backends**: `step-ca` (Smallstep) and local CA key (`ssh-keygen`)
- **Default TTL**: 16 hours (override via `SSH_CERT_TTL` environment variable)
- **CA URL**: Set `SSH_CERT_CA_URL` for `step-ca` integration

## Reporting a Vulnerability

If you discover a security vulnerability, don't open a public issue. Follow the instructions in the Security Policy.
