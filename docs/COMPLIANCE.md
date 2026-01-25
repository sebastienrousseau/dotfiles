# Compliance

This document maps the dotfiles configuration and tooling to standard regulatory frameworks (SOC 2, ISO 27001, GDPR).

## Controls

### SOC 2 Type II

| Control | Description | Dotfiles Implementation |
| :--- | :--- | :--- |
| **CC6.1** | Logical Access Security | `zsh` restricted permissions, SSH key management via `1Password`/Agents. |
| **CC6.8** | Unauthorized Code Protection | `enable-signing` enforces GPG/SSH signed commits. `slsa-framework` workflow. |
| **CC8.1** | Change Management | All changes managed via git (Infrastructure as Code). `lock-configs` for immutability. |
| **A1.2** | Audit Logs | `~/.local/share/dotfiles.log` tracks all configuration applications (`chezmoi apply`). |

### ISO 27001

| Control | Description | Dotfiles Implementation |
| :--- | :--- | :--- |
| **A.9.1.1** | Access Control Policy | Principle of Least Privilege in filesystem permissions (umask 022/077). |
| **A.12.1.2** | Change Management | Git-based version control with CI/CD verification (`ci.yml`, `security-release.yml`). |
| **A.14.2.5** | Secure Engineering | `scan-licenses` (FOSSology) and `check-cla` ensure legal/security compliance. |

### GDPR / HIPAA (Privacy)

| Requirement | Description | Dotfiles Implementation |
| :--- | :--- | :--- |
| **Data Minimization** | Limit data collection | `privacy-mode` disables CLI telemetry (Dotnet, Brew, Functions). |
| **Integrity** | Protect against tampering | `lock-configs` prevents unauthorized modification of shell history/config. |

## Security

### Immutability
Critical configuration files can be locked to prevent tampering:
```bash
lock-configs  # Sets chflags uchg (macOS) or chattr +i (Linux)
```

### Forensic Audit
All `chezmoi` operations are logged. View audit trails:
```bash
dot audit
```

### Supply Chain Security
- **SBOM**: Generated for every release (SPDX format).
- **Provenance**: SLSA Level 3 build attestation.
