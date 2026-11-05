---
render_with_liquid: false
---

# Compliance Architecture

This document describes the compliance, security, and cross-platform compatibility controls implemented in this repository, mapped to standard regulatory frameworks (SOC 2, ISO 27001, GDPR).

## Overview

| Framework | Status | Description |
|-----------|--------|-------------|
| SOC 2 Type II | Aligned | Security, availability, and confidentiality |
| ISO 27001 | Aligned | Information security management controls |
| GDPR/HIPAA | Aligned | Privacy and data protection |
| ISO 13485 | Aligned | Risk management (FMEA), verification & validation |
| ALCOA | Implemented | Audit trail integrity |
| EU AI Act | Exempt | Minimal risk, open-source exemption (Article 2(12)) |

---

## EU AI Act (Regulation (EU) 2024/1689)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| **Risk classification** | Minimal risk | No high-risk use cases (Annex III) |
| **Open-source exemption** | Applicable | Apache-2.0 OR MIT license, no model weights distributed (Article 2(12)) |
| **Prohibited practices** | Confirmed none | No subliminal, exploitative, or social scoring use (Article 5) |
| **Transparency** | Voluntary | Agent session logging, model registry, attestation |
| **GPAI provisions** | Not applicable | Consumer of AI APIs, not a provider |

See [AI_ACT_COMPLIANCE.md](AI_ACT_COMPLIANCE.md) for full assessment.

---

## Regulatory Mapping

### SOC 2 Type II

| Control | Description | Implementation |
|---------|-------------|----------------|
| **CC6.1** | Logical Access Security | `zsh` restricted permissions, SSH key management via `1Password`/Agents |
| **CC6.8** | Unauthorized Code Protection | GPG/SSH signed commits, `slsa-framework` workflow |
| **CC7.1** | System Operations | `compliance-guard.yml` blocks insecure patterns |
| **CC7.2** | Change Detection | Pre-commit hooks detect security violations |
| **CC8.1** | Change Management | Git-based IaC, PR templates, CODEOWNERS |
| **A1.2** | Audit Logs | `${XDG_STATE_HOME:-~/.local/state}/dot/<domain>/log.jsonl` (log.v1) records `dot` apply, doctor, rollback and related operations |

### ISO 27001

| Control | Description | Implementation |
|---------|-------------|----------------|
| **A.9.1.1** | Access Control Policy | Principle of Least Privilege (`umask 022` in `~/.profile` for POSIX and bash login shells; zsh sets none. `umask 077` for private build directories) |
| **A.9.4.1** | Information Access Restriction | `chmod 777/666` blocked by CI |
| **A.12.1.2** | Change Management | Git version control with CI/CD verification |
| **A.12.6.1** | Technical Vulnerability Management | Gitleaks, TruffleHog secrets scanning |
| **A.13.1.1** | Network Controls | TLS enforcement (no `curl -k`) |
| **A.14.2.5** | Secure Engineering | ShellCheck, cross-platform testing |
| **A.14.2.8** | System Security Testing | Module coverage gate (100% in `ci-enforced.yml`), kcov line-coverage floor of 98% (96% for behavioural tests only), weekly scans |

### GDPR / HIPAA (Privacy)

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| **Data Minimization** | Limit data collection | `privacy-mode` disables CLI telemetry |
| **Integrity** | Protect against tampering | `lock-configs` prevents modification |
| **Encryption** | Protect data at rest | Age encryption for sensitive dotfiles |

---

## Security Controls

### TLS Enforcement

All network operations require valid TLS certificates:

| Control | Pattern Blocked | Enforcement |
|---------|-----------------|-------------|
| Insecure curl | `curl -k`, `--insecure` | Pre-commit + CI |
| Certificate bypass | `wget --no-check-certificate` | Pre-commit + CI |
| Plaintext HTTP | `http://` URLs | CI warning |

**Files:**

- Pre-commit: `config/pre-commit-config.yaml`
- CI: `.github/workflows/compliance-guard.yml`

### Secrets Management

| Tool | Purpose | Configuration |
|------|---------|---------------|
| Gitleaks | Prevent secrets in commits | `config/gitleaks.toml` |
| TruffleHog | Deep secrets scanning | CI workflow |
| detect-secrets | Baseline secrets detection | `.secrets.baseline` |
| Age | Encrypt sensitive dotfiles | Chezmoi integration |

### Permission Controls

| Control | Implementation |
|---------|----------------|
| Least privilege CI | `permissions: contents: read` default |
| No world-writable | `chmod 777/666` blocked by CI |
| CODEOWNERS | All paths mapped to reviewers |
| Signed commits | SSH or GPG signatures, required on `main` by branch protection |

### Dangerous Pattern Blocking

Patterns automatically blocked by CI and pre-commit hooks:

```bash
# Blocked - insecure TLS
curl -k https://...
wget --no-check-certificate https://...

# Blocked - world-writable permissions
chmod 777 /path
chmod -R 666 /files

# Blocked - hardcoded credentials
password="literal_value"
```

---

## Cross-Platform Compatibility

### Supported Platforms

| Platform | Tools | Default Shell | Bash Version |
|----------|-------|---------------|--------------|
| Linux | GNU | Bash | 5.x |
| macOS | BSD | Zsh | 3.2 (system) |
| WSL | GNU | Bash | 5.x |

### Line Ending Normalization

Configured in `.gitattributes`:

| Pattern | Line Ending | Reason |
|---------|-------------|--------|
| `*.sh` | LF | Unix scripts |
| `*.bash` | LF | Unix scripts |
| `*.zsh` | LF | Unix scripts |
| `*.bat` | CRLF | Windows batch |
| `*.ps1` | CRLF | PowerShell |

### BSD vs GNU Compatibility

The `cross-platform-test.yml` workflow validates scripts on both platforms:

| Pattern | Issue | Portable Alternative |
|---------|-------|---------------------|
| `sed -i ''` | BSD requires backup ext | Check `$OSTYPE` |
| `sed -i` | GNU style | Check `$OSTYPE` |
| `grep -P` | GNU-only PCRE | Use `grep -E` |
| `date -d` | GNU-only | Use `date +%s` |
| `readarray` | Bash 4+ only | Use `while read` |
| `declare -A` | Bash 4+ only | Use indexed arrays |

### Path Handling

| Requirement | Implementation |
|-------------|----------------|
| No hardcoded user paths | Use `$HOME` or `~` |
| Case-insensitive safe | No filename collisions |
| Cross-platform paths | No platform-specific path literals |

---

## CI/CD Pipeline

### Workflow Matrix

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push/PR | Full CI pipeline, ShellCheck, tests |
| `compliance-guard.yml` | Push/PR | Security pattern scanning |
| `cross-platform-test.yml` | Push/PR + weekly | BSD/GNU compatibility |
| `security-enhanced.yml` | Push/PR + weekly | Deep security analysis (secrets, dependencies, IaC, containers, attestation) |
| `codeql.yml` | Push/PR + weekly | Static code analysis |
| `sbom-diff.yml` | Pull request | SBOM diff and CVE correlation |
| `nightly.yml` | Weekly, Sunday 2 AM UTC | Dependency version checks, extended tests |

SBOMs are generated by `ci.yml` (`Security / SBOM Generation`), per PR by
`sbom-diff.yml`, and per release by `security-release.yml`.

### Compliance Guard Jobs

```text
compliance-guard.yml
├── verify-signatures       # git verify-commit over the PR range (PRs only)
├── insecure-patterns       # TLS, credentials, chmod
├── portability-shell-lint  # ShellCheck portability pass
├── portability             # paths, .gitattributes
├── dockerfile-lint         # Hadolint
└── compliance-summary      # Report generation
```

### Cross-Platform Test Jobs

```text
cross-platform-test.yml
├── changes               # Skip the OS matrix when no shell files changed
├── cross-platform-test   # ubuntu-latest (GNU), macos-latest + macos-15 (BSD)
├── schedule-live         # Scheduled-maintenance run, ubuntu-latest + macos-latest
├── compatibility-report  # Summary
└── gate                  # Single status for the PR
```

### GitHub Actions Security

| Control | Implementation |
|---------|----------------|
| Pinned versions | All actions pinned to SHA or version |
| Minimal permissions | `contents: read` by default |
| Concurrency control | Cancel in-progress duplicates |
| Timeout limits | Most jobs set an explicit `timeout-minutes`; some do not yet |

---

## Pre-Commit Hooks

### Configuration

File: `config/pre-commit-config.yaml` (symlinked as `.pre-commit-config.yaml`)

### Hook Matrix

Selected hooks:

| Hook | Stage | Purpose |
|------|-------|---------|
| `shellcheck` | commit | Shell script linting |
| `shfmt` | commit | Shell script formatting |
| `gitleaks` | commit | Secrets detection |
| `detect-secrets` | commit | Credential scanning |
| `checkov` | pre-push | Infrastructure security |
| `hadolint` | commit | Dockerfile linting |
| `insecure-tls-check` | commit | Block `curl -k` |
| `dangerous-chmod-check` | commit | Block `chmod 777/666` |
| `security-policy-enforcement` | pre-push | Policy validation |

### Installation

The repository's own hooks (`scripts/git-hooks/`) are installed with
`scripts/git-hooks/install.sh`. Its `pre-push` hook enforces commit
signatures and runs the quick reliability audit; its `pre-commit` hook
runs the secret-governance and pre-commit audit scripts. Neither calls
the `pre-commit` framework.

To run the framework hooks above locally instead, install them with the
global `core.hooksPath` hidden (`pre-commit install` refuses to run
while it is set):

```bash
GIT_CONFIG_GLOBAL=/dev/null pre-commit install \
  --hook-type pre-commit --hook-type commit-msg --hook-type pre-push -f
```

This **replaces** `.git/hooks/pre-commit` and `.git/hooks/pre-push`, so
the signature check in `scripts/git-hooks/pre-push` no longer runs
locally. CI runs `pre-commit` on every PR either way (`pre-commit.yml`).

---

## Change Management

### Pull Request Requirements

| Requirement | Implementation |
|-------------|----------------|
| PR template | `.github/PULL_REQUEST_TEMPLATE.md` |
| Code owners | `.github/CODEOWNERS` |
| CI checks | Five required status checks (see `.github/BRANCH_PROTECTION.md`) |
| Review | Requested automatically via CODEOWNERS; no approving review is required (single maintainer) |

### PR Template Checklist

```markdown
- [ ] `chezmoi apply --dry-run` verified
- [ ] Manual testing on macOS
- [ ] Manual testing on Linux
- [ ] CI checks pass
```

### Commit Requirements

| Requirement | Implementation |
|-------------|----------------|
| Signed commits | SSH or GPG signing (cryptographically verified) |
| Conventional format | `feat:`, `fix:`, `docs:` prefixes |
| Co-author attribution | AI contributions attributed |

### Cryptographic Identity Verification (ALCOA: Attributable)

For SOC 2 compliance, the "Attributable" principle requires that all changes are linked to a **verified cryptographic identity**, not just a username.

**Enforcement layers:**

| Layer | Mechanism | Status |
|-------|-----------|--------|
| Local | Pre-push hook blocks unsigned commits | Enforced (skipped by `--no-verify`) |
| CI | `compliance-guard.yml` `Verify Commit Signatures` job fails on an unsigned commit | Enforced in the job; not a required check |
| GitHub | Branch protection "Require signed commits", enforced for admins | Enforced |

**Pre-push hook location:** `scripts/git-hooks/pre-push`

```bash
# The hook verifies each commit before push:
for c in $(git rev-list "$range"); do
  if ! git verify-commit "$c" >/dev/null 2>&1; then
    echo "Blocked: unsigned commit $c"
    exit 1
  fi
done
```

**Setup signing:**

```bash
# SSH signing (recommended)
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# GPG signing (alternative)
git config --global user.signingkey <YOUR_GPG_KEY_ID>
git config --global commit.gpgsign true

# Or use the dotfiles alias:
enable-signing ssh  # or: enable-signing gpg
```

**Install pre-push hook:**

```bash
scripts/git-hooks/install.sh
```

**GitHub Branch Protection:**

"Require signed commits" is enabled on `main`. Check it with
`gh api repos/sebastienrousseau/dotfiles/branches/main/protection --jq .required_signatures.enabled`.

---

## Test Coverage

### Coverage Gates

| Gate | Threshold | Where |
|------|-----------|-------|
| Module coverage (`tests/framework/module_coverage.sh`) | 100% | `ci-enforced.yml` `test-unit` |
| kcov line coverage | 98% floor | `coverage.yml` `Coverage / kcov` |
| kcov, behavioural tests only | 96% floor | `coverage.yml` |
| Test pass rate | 100% (zero failed tests) | `ci-enforced.yml` |

### Test Framework

```text
tests/
├── framework/
│   ├── assertions.sh    # assertion functions
│   ├── mocks.sh         # Mock utilities
│   └── test_runner.sh   # Test executor
├── unit/
│   └── <domain>/test_*.sh   # unit tests, grouped by domain
├── integration/
│   └── test_*.sh        # integration tests
├── regression/          # regression and static-analysis tests
└── benchmark.sh         # benchmarks
```

### Running Tests

```bash
# Run all tests
./tests/framework/test_runner.sh

# Run specific test
bash tests/unit/core/<test_file>.sh
```

---

## Security Documentation

### Required Files

| File | Purpose | Location |
|------|---------|----------|
| SECURITY.md | Vulnerability reporting | `SECURITY.md` |
| CONTRIBUTING.md | Contribution guidelines | `.github/CONTRIBUTING.md` |
| CODEOWNERS | Code ownership | `.github/CODEOWNERS` |
| INCIDENT_RESPONSE.md | Incident response plan | `docs/security/` |
| FMEA.md | Failure Mode & Effects Analysis | `docs/security/` |
| VERIFICATION_VALIDATION.md | ISO 13485-style V&V report | `docs/security/` |
| .editorconfig | Editor settings | Root |
| .gitattributes | Git attributes | Root |

### Vulnerability Response SLA

| Severity | Initial Response | Resolution Target |
|----------|------------------|-------------------|
| Critical | 24 hours | 48 hours |
| High | 72 hours | 7 days |
| Medium | 5 business days | 30 days |
| Low | 10 business days | 90 days |

---

## Audit & Forensics

### Immutability

Lock critical configuration files:

```bash
lock-configs  # Sets chflags uchg (macOS) or chattr +i (Linux)
```

### Audit Trail

```bash
# View the dotfiles operations logs (one per domain), newest last
cat "${XDG_STATE_HOME:-$HOME/.local/state}"/dot/*/log.jsonl | sort -s -t'"' -k8,8 | tail -n 50
```

Each line is a log.v1 record (`schemas/cli/log.v1.schema.json`); the
maintenance job prunes records older than `DOT_LOG_RETENTION_DAYS` (30).
The `dot-audit` alias shows the last 20, and falls back to `git log` when
there are none yet.

### Supply Chain Security

| Control | Implementation |
|---------|----------------|
| SBOM | Generated for every release (SPDX) |
| Provenance | SLSA Level 3 build attestation |
| Dependencies | Pinned versions, weekly updates |

---

## Verification Commands

### Manual Verification

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Run unit tests
./tests/framework/test_runner.sh

# Check for insecure patterns
grep -rn --include="*.sh" -E 'curl.*-k|wget.*--no-check' .

# Validate .gitattributes
grep "text=auto" .gitattributes && echo "OK"
```

### Automated Verification

| Schedule | Check |
|----------|-------|
| Every PR | compliance-guard, cross-platform-test |
| Weekly | Full security scan, CodeQL, tool version checks (`nightly.yml`) |

---

## References

- [SOC 2 Type II](https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2)
- [ISO 27001:2022](https://www.iso.org/standard/27001)
- [OWASP Top 10](https://owasp.org/Top10/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [SLSA Framework](https://slsa.dev/)
