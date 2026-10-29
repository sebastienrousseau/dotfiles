---
render_with_liquid: false
---

# Security Documentation

This directory contains security documentation for the dotfiles project.

## Index

### Policy and reporting

| Document | Description |
|----------|-------------|
| [SECURITY.md](SECURITY.md) | Core security model and opt-in hardening |
| [DISCLOSURE.md](DISCLOSURE.md) | Encrypted vulnerability reporting workflow |
| [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) | Incident response plan and runbooks |
| [THREAT_MODEL.md](THREAT_MODEL.md) | Threat analysis with trust boundaries |

### Keys, secrets and signing

| Document | Description |
|----------|-------------|
| [SECRETS.md](SECRETS.md) | Secrets management (Age, SOPS, Keychain) |
| [ENCRYPTION.md](ENCRYPTION.md) | Secrets encryption with SOPS and age |
| [KEY_ROTATION.md](KEY_ROTATION.md) | Disclosure key and secrets key rotation |
| [COMMIT_SIGNING.md](COMMIT_SIGNING.md) | Commit signing policy, setup and enforcement layers |
| [AUTOMATION_SECRETS.md](AUTOMATION_SECRETS.md) | Secrets used by CI automation |
| [HISTORY_FILTERING.md](HISTORY_FILTERING.md) | Atuin history filtering of secrets |
| [AUDIT_BYPASS.md](AUDIT_BYPASS.md) | Pre-push audit bypass policy |

### Supply chain and CI

| Document | Description |
|----------|-------------|
| [CI_PINNING.md](CI_PINNING.md) | CI dependency pinning policy |
| [CI_EGRESS_ALLOWLIST.md](CI_EGRESS_ALLOWLIST.md) | harden-runner egress allowlist |
| [DEPS_DEV_EXCEPTIONS.md](DEPS_DEV_EXCEPTIONS.md) | deps.dev advisory exceptions |
| [SHELL_EXEMPTIONS.md](SHELL_EXEMPTIONS.md) | Shell preamble (`set -euo pipefail`) exemptions |
| [SCORECARD.md](SCORECARD.md) | OpenSSF Scorecard posture and open findings |
| [FUZZING.md](FUZZING.md) | Fuzz harnesses and how they run |
| [INSTALL_VERIFICATION.md](INSTALL_VERIFICATION.md) | Verifying the installer before running it |
| [VERIFY_RELEASE.md](VERIFY_RELEASE.md) | Verifying a release |
| [POLICY_RELEASES.md](POLICY_RELEASES.md) | Policy bundle releases |
| [MCP_POLICY.md](MCP_POLICY.md) | MCP server policy |

### Compliance and quality

| Document | Description |
|----------|-------------|
| [COMPLIANCE.md](COMPLIANCE.md) | SOC 2, ISO 27001, GDPR, HIPAA mapping |
| [AI_ACT_COMPLIANCE.md](AI_ACT_COMPLIANCE.md) | EU AI Act risk classification and exemption analysis |
| [FMEA.md](FMEA.md) | Failure mode and effects analysis |
| [VERIFICATION_VALIDATION.md](VERIFICATION_VALIDATION.md) | Verification and validation report |
| [SOUP_REGISTER.md](SOUP_REGISTER.md) | Software of unknown pedigree register |
| [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) | Pre-release security verification |

### Other

| Document | Description |
|----------|-------------|
| [KEYS.md](KEYS.md) | Keybindings reference (keyboard shortcuts, not cryptographic keys; kept here because other pages link to this path) |

The GPG public key for encrypted reports is
[`security-pubkey.asc`](security-pubkey.asc).

## Quick Reference

- **Encryption:** Age + SOPS for secrets at rest
- **Signing:** Signed commits required on `main` by branch protection; SSH ED25519 recommended
- **Scanning:** Gitleaks in the pre-commit config and in CI (`Security / Secrets Scan`) catches credential leaks
- **Telemetry:** Disabled by default, no data leaves your machine
- **Hardening:** Opt-in firewall, DNS-over-HTTPS, lock-screen, USB safety
