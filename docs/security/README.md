# Security Documentation

This directory contains security documentation for the dotfiles project.

## Index

| Document | Description |
|----------|-------------|
| [SECURITY.md](SECURITY.md) | Core security model and opt-in hardening |
| [THREAT_MODEL.md](THREAT_MODEL.md) | Threat analysis with trust boundaries |
| [SECRETS.md](SECRETS.md) | Secrets management (Age, SOPS, Keychain) |
| [KEY_ROTATION.md](KEY_ROTATION.md) | Key rotation procedures |
| [KEYS.md](KEYS.md) | Keybindings reference |
| [COMPLIANCE.md](COMPLIANCE.md) | SOC 2, ISO 27001, GDPR, HIPAA mapping |
| [AI_ACT_COMPLIANCE.md](AI_ACT_COMPLIANCE.md) | EU AI Act risk classification and exemption analysis |
| [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) | Pre-release security verification |

## Quick Reference

- **Encryption:** Age + SOPS for secrets at rest
- **Signing:** SSH ED25519 commit signing enforced
- **Scanning:** Gitleaks pre-commit hook prevents credential leaks
- **Telemetry:** Disabled by default, no data leaves your machine
- **Hardening:** Opt-in firewall, DNS-over-HTTPS, lock-screen, USB safety
