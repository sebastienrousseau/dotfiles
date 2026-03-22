# Failure Mode and Effects Analysis (FMEA)

Systematic risk assessment of the chezmoi-managed dotfiles repository per IEC 60812 methodology. Identifies failure modes, quantifies risk priority, and documents mitigations across all configuration management subsystems.

## Purpose

This document applies Failure Mode and Effects Analysis (FMEA) to a chezmoi-managed dotfiles repository. Each failure mode is evaluated by Severity, Occurrence, and Detection ratings to produce a Risk Priority Number (RPN). The RPN drives mitigation priority and review cadence.

Methodology: IEC 60812:2018 — Analysis techniques for system reliability.

## Scope

| Domain | Coverage |
|--------|----------|
| Shell configuration | Zsh, Fish, Nushell startup, aliases, functions, `rc.d` modules |
| Tool management | mise, Homebrew, Nix flakes, Zinit plugins, Neovim plugins |
| Secrets management | Age encryption, gitleaks, 1Password integration, Atuin history |
| CI/CD pipeline | GitHub Actions workflows, pre-commit hooks, compliance guards |
| Cross-platform deployment | macOS (BSD), Linux (GNU), WSL, chezmoi templating |
| Git integrity | Signed commits, branch protection, CODEOWNERS |

---

## Rating Scales

### Severity (S)

| Rating | Level | Definition |
|--------|-------|------------|
| 1 | None | No effect on system operation |
| 2 | Very Minor | Cosmetic defect noticed only by maintainer |
| 3 | Minor | Minor degradation, workaround available |
| 4 | Very Low | Subsystem partially impaired, user notices |
| 5 | Low | Subsystem degraded, reduced functionality |
| 6 | Moderate | System operates with degraded performance |
| 7 | High | System operates but critical function impaired |
| 8 | Very High | System inoperable, data at risk |
| 9 | Hazardous with Warning | Potential security breach, credentials exposed |
| 10 | Hazardous without Warning | Secret exfiltration, supply chain compromise, silent data loss |

### Occurrence (O)

| Rating | Level | Definition |
|--------|-------|------------|
| 1 | Nearly Impossible | < 1 in 1,000,000 operations |
| 2 | Remote | 1 in 100,000 operations |
| 3 | Very Low | 1 in 10,000 operations |
| 4 | Low | 1 in 1,000 operations |
| 5 | Moderate | 1 in 200 operations |
| 6 | Moderately High | 1 in 50 operations |
| 7 | High | 1 in 20 operations |
| 8 | Very High | 1 in 10 operations |
| 9 | Extremely High | 1 in 3 operations |
| 10 | Certain | Every operation |

### Detection (D)

| Rating | Level | Definition |
|--------|-------|------------|
| 1 | Almost Certain | Automated control detects failure every time |
| 2 | Very High | Automated control with >99% detection rate |
| 3 | High | Automated test catches most occurrences |
| 4 | Moderately High | CI pipeline detects on PR merge |
| 5 | Moderate | Detected during routine manual review |
| 6 | Low | Detected only by targeted audit |
| 7 | Very Low | Requires manual inspection to discover |
| 8 | Remote | Detected only after user reports failure |
| 9 | Very Remote | Detected only after external incident |
| 10 | Undetectable | No mechanism exists to detect the failure |

---

## FMEA Table

| ID | Component | Failure Mode | Effect | S | O | D | RPN | Mitigation | Status |
|----|-----------|-------------|--------|---|---|---|-----|------------|--------|
| FM-01 | Secrets Management | Secrets committed to git (gitleaks bypass) | API keys, tokens, or passwords exposed in public git history | 10 | 3 | 2 | 60 | Gitleaks pre-commit hook, TruffleHog CI scan, detect-secrets baseline, `.gitignore` excludes `key.txt`/`.env` | Mitigated |
| FM-02 | Shell Configuration | `chezmoi apply` corrupts shell config | Login shell fails to start, user locked out of interactive session | 9 | 3 | 3 | 81 | `chezmoi apply --dry-run` in CI, `chezmoi diff` pre-check, version-controlled rollback via `git checkout` | Mitigated |
| FM-03 | Git Integrity | Unsigned commit pushed (GPG/SSH bypass) | Commit attribution unverifiable, compliance violation (SOC 2 CC6.8) | 7 | 4 | 2 | 56 | Pre-push hook verifies signatures, `compliance-guard.yml` CI check, `commit.gpgsign = true` default | Mitigated |
| FM-04 | Tool Management | mise tool update introduces vulnerability | Compromised binary executes with user privileges on every shell start | 10 | 2 | 6 | 120 | Pinned tool versions in `.tool-versions`, Nix flake lock reproducibility, manual version audit | Monitoring |
| FM-05 | Shell Performance | Shell startup exceeds 500ms | Degraded developer experience, productivity loss, user disables safety features | 5 | 5 | 3 | 75 | `_cached_eval` mtime-based caching, `DOTFILES_ULTRA_FAST=1` bypass, `dot health` startup benchmark | Mitigated |
| FM-06 | Cross-Platform | BSD vs GNU incompatibility | Script fails silently or produces incorrect output on macOS or Linux | 6 | 5 | 3 | 90 | `cross-platform-test.yml` CI on macOS + Linux, `$OSTYPE` guards, portable alternatives documented in COMPLIANCE.md | Mitigated |
| FM-07 | CI/CD Pipeline | CI workflow tampered (Actions injection) | Attacker executes arbitrary code in CI, exfiltrates secrets, modifies artifacts | 10 | 2 | 4 | 80 | Actions pinned to SHA, `permissions: contents: read` default, concurrency control, explicit job timeouts | Mitigated |
| FM-08 | Secrets Management | Age encryption key lost | Encrypted dotfiles unrecoverable, secrets permanently inaccessible | 9 | 2 | 8 | 144 | Key backup in 1Password vault, documented recovery procedure in KEYS.md, periodic backup verification | Monitoring |
| FM-09 | Shell Configuration | Alias conflict breaks existing command | User command produces unexpected behavior, data loss in destructive operations | 7 | 4 | 5 | 140 | Alias naming conventions (`chezmoi_` prefix for internal), unit tests for all 99 alias files, `type` command verification | Monitoring |
| FM-10 | Tool Management | Nix flake lock stale (>30 days) | Outdated dependencies with known vulnerabilities, reproducibility drift | 6 | 6 | 4 | 144 | `nightly.yml` dependency version checks, `nix flake update` in maintenance schedule, `dot health` staleness check | Monitoring |
| FM-11 | Git Integrity | Pre-commit hook bypassed (`--no-verify`) | Secrets, lint failures, and insecure patterns reach the repository | 8 | 4 | 7 | 224 | CI re-runs all pre-commit checks (`compliance-guard.yml`), branch protection requires CI pass, audit log review | Mitigated |
| FM-12 | Cross-Platform | Config drift between machines | Inconsistent behavior across workstations, unreproducible environments | 5 | 5 | 6 | 150 | Chezmoi state management, `chezmoi status` diff check, feature flags in `.chezmoidata.toml`, CI dry-run on both platforms | Monitoring |
| FM-13 | Network Security | TLS certificate validation disabled | Man-in-the-middle interception of downloads, credential theft | 10 | 2 | 2 | 40 | `curl -k` and `wget --no-check-certificate` blocked by pre-commit and CI, pattern scanning in `compliance-guard.yml` | Mitigated |
| FM-14 | File Permissions | World-writable file permissions (chmod 777) | Any local user or process can modify configs, privilege escalation vector | 9 | 2 | 2 | 36 | `chmod 777/666` blocked by pre-commit and CI, chezmoi `private_` prefix enforces 0600, `umask 022` default | Mitigated |
| FM-15 | Template Engine | Template rendering failure (`.tmpl` syntax error) | Chezmoi apply fails, partial deployment leaves inconsistent state | 7 | 4 | 2 | 56 | `chezmoi apply --dry-run` in CI on Linux + macOS, template syntax validated before merge, `chezmoi execute-template` for local testing | Mitigated |

---

## Risk Priority Summary

### Critical (RPN > 200)

| ID | Component | Failure Mode | RPN | Action Required |
|----|-----------|-------------|-----|-----------------|
| FM-11 | Git Integrity | Pre-commit hook bypassed (`--no-verify`) | 224 | CI enforcement layer catches all bypassed checks; add GitHub branch protection rule requiring status checks to pass |

### High (RPN 100-200)

| ID | Component | Failure Mode | RPN | Action Required |
|----|-----------|-------------|-----|-----------------|
| FM-12 | Cross-Platform | Config drift between machines | 150 | Implement `chezmoi status` in `dot health` dashboard; alert on drift >24 hours |
| FM-10 | Tool Management | Nix flake lock stale (>30 days) | 144 | Enforce flake freshness check in nightly CI; auto-create PR on staleness |
| FM-08 | Secrets Management | Age encryption key lost | 144 | Quarterly key backup verification; document recovery runbook |
| FM-09 | Shell Configuration | Alias conflict breaks existing command | 140 | Expand alias unit tests with conflict detection; `type` validation in CI |
| FM-04 | Tool Management | mise tool update introduces vulnerability | 120 | Pin versions, audit changelogs before updates, monitor CVE databases |

### Medium (RPN 50-100)

| ID | Component | Failure Mode | RPN | Action Required |
|----|-----------|-------------|-----|-----------------|
| FM-06 | Cross-Platform | BSD vs GNU incompatibility | 90 | Maintain cross-platform CI matrix; document portable alternatives |
| FM-02 | Shell Configuration | `chezmoi apply` corrupts shell config | 81 | CI dry-run enforcement; rollback documentation |
| FM-07 | CI/CD Pipeline | CI workflow tampered (Actions injection) | 80 | SHA-pinned actions; minimal permissions; periodic audit |
| FM-05 | Shell Performance | Shell startup exceeds 500ms | 75 | Performance regression tests in CI; cache warming |
| FM-01 | Secrets Management | Secrets committed to git (gitleaks bypass) | 60 | Multi-layered scanning (pre-commit + CI + detect-secrets) |
| FM-03 | Git Integrity | Unsigned commit pushed (GPG/SSH bypass) | 56 | Pre-push hook + CI verification |
| FM-15 | Template Engine | Template rendering failure (`.tmpl` syntax error) | 56 | CI dry-run on both platforms |

### Low (RPN < 50)

| ID | Component | Failure Mode | RPN | Action Required |
|----|-----------|-------------|-----|-----------------|
| FM-13 | Network Security | TLS certificate validation disabled | 40 | Automated pattern blocking; no further action |
| FM-14 | File Permissions | World-writable file permissions (chmod 777) | 36 | Automated pattern blocking; no further action |

---

## Review Schedule

| Activity | Cadence | Owner | Deliverable |
|----------|---------|-------|-------------|
| FMEA full review | Quarterly | Repository maintainer | Updated FMEA table, revised RPNs |
| RPN recalculation | After each mitigation change | Repository maintainer | Updated RPN values, status changes |
| Critical item review | Monthly | Repository maintainer | Action items for RPN > 200 |
| New failure mode triage | Per incident | Repository maintainer | New FMEA row, initial RPN assignment |
| Detection control audit | Quarterly | Repository maintainer | Verify automated controls function correctly |
| Mitigation effectiveness | Semi-annually | Repository maintainer | Compare actual vs predicted occurrence rates |

**Next scheduled review:** 2026-06-20

---

## References

- [IEC 60812:2018](https://www.iso.org/standard/64076.html) — Analysis techniques for system reliability
- [AIAG FMEA Handbook](https://www.aiag.org/quality/automotive-core-tools/fmea) — Automotive Industry Action Group FMEA methodology
- [COMPLIANCE.md](COMPLIANCE.md) — Regulatory mapping and security controls
- [THREAT_MODEL.md](THREAT_MODEL.md) — Trust boundaries and attack surface analysis
- [SECURITY.md](SECURITY.md) — Vulnerability reporting and response SLAs
