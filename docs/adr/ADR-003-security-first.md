# ADR-003: Security-First Approach

**Status**: Accepted
**Date**: 2026-02-09
**Authors**: @sebastienrousseau

## Context

Dotfiles repositories present unique security challenges:
- They configure system behavior and permissions
- They may contain or reference secrets (API keys, tokens)
- They execute scripts with user privileges
- They're often cloned to multiple machines

A security breach in dotfiles can compromise all systems using them.

## Decision

Implement a **defense-in-depth security model** with multiple layers:

### Layer 1: Secrets Protection

**Never commit secrets:**
```bash
# .gitleaks.toml - block common secret patterns
[[rules]]
id = "generic-api-key"
regex = '''(?i)(api[_-]?key|apikey)\s*[:=]\s*['"]?([a-zA-Z0-9]{20,})'''
```

**Encrypted secrets with age:**
```bash
# Secrets stored encrypted, decrypted at apply time
chezmoi.encryption = "age"
chezmoi.age.identity = "~/.config/chezmoi/key.txt"
```

**CI enforcement:**
- Gitleaks runs on every PR
- TruffleHog for verified secrets detection
- Block merge if secrets detected

### Layer 2: Input Validation

**Path traversal prevention:**
```bash
# Validate all user inputs
if [[ ! "$template_lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  die "Invalid template name: $template_lang"
fi
```

**Safe file operations:**
```bash
# Use absolute paths, validate before operations
local real_path
real_path="$(realpath -m "$user_input")"
if [[ "$real_path" != "$allowed_base"/* ]]; then
  die "Path outside allowed directory"
fi
```

### Layer 3: Opt-in System Modifications

**Dangerous operations require explicit consent:**
```bash
# Security scripts are opt-in
if [ "${DOTFILES_SECURITY:-0}" != "1" ]; then
  echo "Security hardening is opt-in. Set DOTFILES_SECURITY=1 to enable."
  exit 0
fi
```

**Comprehensive logging:**
```bash
# All system modifications logged
log_security_change() {
  echo "[$(date -Iseconds)] $1" >> "$HOME/.local/share/dotfiles-security.log"
}
```

### Layer 4: CI Security Scanning

**Multi-tool approach:**
- **Gitleaks**: Secrets in git history
- **Shellcheck**: Shell script vulnerabilities
- **Checkov**: Infrastructure misconfigurations
- **Trivy**: Container vulnerabilities (when applicable)
- **CodeQL**: Static analysis for Python/JavaScript

**Weekly deep scans:**
```yaml
schedule:
  - cron: '0 2 * * 0'  # Weekly security audit
```

### Layer 5: Minimal Privileges

**Scripts request only needed permissions:**
```bash
# Don't run as root unless necessary
if [ "$(id -u)" = "0" ]; then
  die "This script should not run as root"
fi

# Use sudo only for specific commands
sudo sysctl -w net.ipv4.tcp_keepalive_time=60
```

## Consequences

### Positive
- Secrets never enter git history
- System modifications are auditable
- Multiple layers catch different vulnerability types
- Contributors have clear security patterns to follow

### Negative
- Additional complexity in scripts
- Encrypted secrets require key management
- Some features disabled by default (friction)

### Neutral
- Security vs convenience trade-offs explicit
- Regular security audits via scheduled CI

## Security Checklist for Contributors

- [ ] No hardcoded secrets (use environment variables or age encryption)
- [ ] Validate all user inputs
- [ ] Use absolute paths for file operations
- [ ] Document any system modifications
- [ ] Test scripts with shellcheck
- [ ] Add appropriate permission checks

## References

- [OWASP Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [Age Encryption](https://github.com/FiloSottile/age)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
