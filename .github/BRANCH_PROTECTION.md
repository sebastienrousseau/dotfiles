# Branch Protection Configuration

This document defines the required branch protection rules for enforcing zero-warning CI policy.

## Required Status Checks

The following status checks **MUST** pass before merge is allowed:

### Core Quality Gates
- `lint-shell` - Zero-warning shellcheck policy
- `lint-lua` - Zero-warning luacheck policy
- `security-secrets` - Zero-tolerance secrets scanning
- `security-dependencies` - Supply chain security audit
- `test-unit` - 100% test success rate (fail-under 100%)
- `quality-gate` - Final validation checkpoint

### Security Gates (from security-enhanced.yml)
- `gitleaks` - Advanced secret detection
- `checkov` - Infrastructure security scan
- `dependency-check` - Known vulnerability scan

## Branch Protection Settings

Configure these settings in GitHub repository settings:

```yaml
protection_rules:
  master:
    required_status_checks:
      strict: true  # Require branches to be up to date before merging
      contexts:
        - "lint-shell"
        - "lint-lua"
        - "security-secrets"
        - "security-dependencies"
        - "test-unit"
        - "quality-gate"
    enforce_admins: true
    required_pull_request_reviews:
      required_approving_review_count: 1
      dismiss_stale_reviews: true
      require_code_owner_reviews: true
    restrictions: null  # No push restrictions
    required_linear_history: true
    allow_force_pushes: false
    allow_deletions: false
```

## Zero-Warning Policy Enforcement

### Linting Rules
- **Shellcheck**: No warnings except SC1091, SC2030, SC2031 (CI-specific false positives)
- **Luacheck**: All warnings treated as errors (`--fail` flag enforced)
- **Shfmt**: Formatting violations cause immediate failure
- **Stylua**: Formatting violations cause immediate failure

### Test Coverage Requirements
- **Unit Tests**: 100% success rate required (zero failed tests)
- **Integration Tests**: 100% success rate required
- **Performance Tests**: Shell startup must be <500ms
- **Security Tests**: Zero secrets, zero vulnerabilities

### Security Policy
- **No `|| true` patterns** on security-critical steps
- **No piped execution** (`curl ... | sh` patterns forbidden)
- **Mandatory secret scanning** on every commit
- **Supply chain validation** for all external dependencies

## Bypass Procedures

### Emergency Hotfix Process
1. Create hotfix branch from `master`
2. Apply minimal fix with full justification
3. Request emergency review from CODEOWNERS
4. Merge with admin override if critical security issue
5. Follow up with full CI compliance within 24 hours

### Maintenance Bypass
- **NEVER** bypass for convenience
- **NEVER** use `--no-verify` git flags
- **NEVER** disable required status checks permanently

## Monitoring & Alerting

### Nightly Reports
- Dependency update notifications
- Performance regression tracking
- Extended security scanning results
- Beta tool compatibility reports

### Failure Response
- All CI failures must be addressed before merge
- Performance regressions trigger automatic alerts
- Security violations escalate to immediate review
- Dependency vulnerabilities block merge automatically

## Implementation Commands

Apply branch protection via GitHub CLI:

```bash
# Set branch protection rules
gh api repos/:owner/:repo/branches/master/protection \
  --method PUT \
  --input protection-rules.json

# Verify protection is active
gh api repos/:owner/:repo/branches/master/protection \
  --jq '.required_status_checks.contexts[]'
```

## Quality Metrics

### Success Criteria
- ✅ Zero linting warnings across all languages
- ✅ 100% test pass rate (no failed tests)
- ✅ Zero security vulnerabilities
- ✅ Performance within thresholds
- ✅ All dependencies up-to-date and secure

### Failure Escalation
- 🚨 Any security scan failure blocks merge immediately
- ⚠️ Performance regression creates GitHub issue automatically
- 🔄 Test failures require fix + re-run of full CI suite
- 📦 Dependency vulnerabilities trigger security review

---

**Note**: This zero-warning policy ensures maximum code quality and security. All violations must be fixed - no exceptions or workarounds permitted.