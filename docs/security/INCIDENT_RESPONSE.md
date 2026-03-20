# Incident Response Plan

Incident response procedures for the dotfiles repository. Covers supply chain compromise, secrets exposure, configuration drift, tool tampering, and CI pipeline attacks. Based on NIST SP 800-61 Rev. 2 (Computer Security Incident Handling Guide).

## Purpose and Scope

This plan defines the detection, triage, containment, eradication, recovery, and post-mortem procedures for security incidents affecting the dotfiles distribution.

### In Scope

| Domain | Description |
|--------|-------------|
| Supply chain | Dependency tampering in Homebrew, Nix, Zinit, Neovim plugins, npm, pip |
| Secrets exposure | API keys, SSH keys, tokens leaked to git history, shell history, or logs |
| Configuration drift | Unauthorized changes to deployed dotfiles, chezmoi apply failures |
| Tool compromise | Malicious updates to mise, Nix, or Homebrew-managed binaries |
| CI pipeline | GitHub Actions workflow tampering, compromised action dependencies |

### Out of Scope

| Domain | Reason |
|--------|--------|
| Operating system vulnerabilities | Managed by OS vendor security updates |
| Hardware compromise | Physical security is outside repository scope |
| Third-party SaaS breaches | Upstream provider responsibility (1Password, GitHub) |

---

## Severity Classification Matrix

Severity levels and response times align with the Vulnerability Response SLA defined in [COMPLIANCE.md](COMPLIANCE.md).

| Severity | Definition | Examples | Initial Response | Resolution Target |
|----------|------------|----------|------------------|-------------------|
| **Critical** | Active exploitation or secrets exposed in public repository | Leaked API key in git history; compromised CI workflow pushing malicious code; active credential abuse | 24 hours | 48 hours |
| **High** | Confirmed compromise with no evidence of active exploitation | Unsigned commits merged to main; supply chain dependency with known CVE; tampered binary in PATH | 72 hours | 7 days |
| **Medium** | Policy violation or misconfiguration with limited blast radius | Chezmoi apply drift on non-sensitive config; TLS bypass pattern in script; stale Nix flake lock | 5 business days | 30 days |
| **Low** | Informational finding, hardening opportunity, or cosmetic policy gap | Missing CODEOWNERS entry; advisory shellcheck warning; outdated pinned version | 10 business days | 90 days |

---

## Incident Response Phases

### Phase 1: Detection

Identify the incident through automated or manual signals.

**Automated detection sources:**

| Source | Signal | Tool |
|--------|--------|------|
| Pre-commit hooks | Blocked secret, insecure pattern | Gitleaks, detect-secrets, compliance-guard |
| CI pipeline | Failed security scan, unsigned commit | `security-enhanced.yml`, `compliance-guard.yml` |
| Nightly checks | Dependency version drift, CVE match | `nightly.yml` |
| CodeQL | Static analysis finding | `codeql.yml` |
| Audit log | Unexpected operation | `dot audit` (`~/.local/share/dotfiles.log`) |

**Manual detection signals:**

- Unexpected `chezmoi diff` output on a clean system
- Unrecognized entries in `git log --show-signature`
- Binary hash mismatch for tools in `~/.local/bin`
- Shell startup latency spike (possible injected sourcing)

### Phase 2: Triage

Classify the incident severity and assign ownership.

```bash
# Gather initial evidence
dot audit | tail -50
git log --oneline --show-signature -20
chezmoi diff
chezmoi verify

# Check for secrets in recent history
gitleaks detect --source . --log-opts="-20"

# Validate binary integrity
mise ls --current
nix flake metadata
```

**Triage decision tree:**

1. Are credentials or secrets exposed publicly? -> **Critical**
2. Is a signed commit chain broken? -> **High**
3. Is the CI pipeline producing unexpected artifacts? -> **High**
4. Is configuration drift limited to non-sensitive files? -> **Medium**
5. Is the finding advisory with no active risk? -> **Low**

### Phase 3: Containment

Stop the incident from spreading. Actions depend on severity.

**Immediate containment (Critical/High):**

```bash
# Revoke exposed credentials
dot secrets rotate --all-exposed

# Revoke SSH certificates
dot ssh-cert revoke

# Lock configuration files to prevent further modification
lock-configs

# Disable compromised CI workflow
gh workflow disable <workflow-name>

# Force-protect the main branch
gh api repos/{owner}/{repo}/branches/master/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["ci"]}' \
  --field enforce_admins=true
```

**Short-term containment (Medium/Low):**

```bash
# Pin the affected dependency to a known-good version
# In .chezmoidata.toml or flake.nix, revert to last verified version

# Re-apply known-good configuration
chezmoi apply --force

# Clear potentially tainted caches
rm -rf ~/.cache/shell/
```

### Phase 4: Eradication

Remove the root cause of the incident.

| Incident Type | Eradication Action |
|---------------|-------------------|
| Secrets in git history | Rewrite history with `git filter-repo`; rotate all exposed credentials |
| Compromised dependency | Pin to patched version; update `flake.lock` or `lazy-lock.json` |
| Unsigned commits | Rebase and re-sign the commit chain; enforce branch protection |
| Tampered binary | Reinstall from verified source; validate checksums |
| CI workflow compromise | Audit workflow diff; re-pin actions to verified SHA; rotate `GITHUB_TOKEN` |

### Phase 5: Recovery

Restore normal operations and verify integrity.

```bash
# Re-apply dotfiles from clean source
chezmoi init --apply

# Verify deployed state matches source
chezmoi verify

# Run full test suite
./tests/framework/test_runner.sh

# Run compliance checks
pre-commit run --all-files

# Validate system health
dot health
dot doctor

# Confirm audit log captures recovery
dot audit | tail -20
```

### Phase 6: Post-Mortem

Conduct a structured review within 5 business days of resolution. Use the [Post-Incident Review Template](#post-incident-review-template) below.

---

## Runbooks

### Runbook 1: Secrets Leaked to Git History

**Detection:** Gitleaks pre-commit hook, TruffleHog CI scan, or manual discovery.

```bash
# Step 1: Identify exposed secrets
gitleaks detect --source . --verbose --report-path /tmp/gitleaks-report.json

# Step 2: Determine exposure window
git log --all --oneline --diff-filter=A -- '**/.*env*' '**/*key*' '**/*token*'

# Step 3: Rotate all exposed credentials immediately
# API keys: regenerate in provider dashboard
# SSH keys: generate new keypair and update authorized_keys
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new
# Tokens: revoke and reissue via provider

# Step 4: Remove secrets from git history
git filter-repo --invert-paths --path <file-containing-secret>

# Step 5: Force-push cleaned history (requires branch protection override)
git push origin --force --all

# Step 6: Notify GitHub to purge cached views
# Open a support ticket at https://support.github.com for cache invalidation

# Step 7: Update Gitleaks baseline
gitleaks detect --source . --baseline-path config/gitleaks-baseline.json

# Step 8: Verify clean state
gitleaks detect --source . --verbose
```

**Post-action:** Add the leaked pattern to `config/gitleaks.toml` allowlist if it was a false positive, or add a new rule if the pattern was not previously covered.

### Runbook 2: Supply Chain Compromise

**Detection:** CVE advisory, unexpected binary behavior, hash mismatch, or `nightly.yml` alert.

```bash
# Step 1: Identify the compromised package
mise ls --current
brew list --versions
nix flake metadata

# Step 2: Check upstream advisories
gh api /advisories --jq '.[] | select(.package.name == "<package>")'

# Step 3: Pin to last known-good version
# For Nix: revert flake.lock to known-good commit
git checkout <known-good-commit> -- flake.lock
nix flake lock --update-input nixpkgs

# For Homebrew: pin the formula
brew pin <formula>

# For mise: set explicit version
mise use <tool>@<safe-version>

# Step 4: Verify integrity of installed binary
sha256sum "$(which <tool>)"
# Compare against published checksums from upstream release

# Step 5: Re-apply configuration with clean dependencies
chezmoi apply --force

# Step 6: Run full test suite to detect behavioral changes
./tests/framework/test_runner.sh
```

### Runbook 3: Configuration Drift

**Detection:** `chezmoi diff` shows unexpected changes, `chezmoi verify` fails, or `dot health` reports drift.

```bash
# Step 1: Identify drift scope
chezmoi diff
chezmoi managed --include=files | wc -l

# Step 2: Capture current deployed state for forensic comparison
chezmoi dump --format=json > /tmp/chezmoi-state-$(date +%s).json

# Step 3: Check audit log for unauthorized operations
dot audit | grep -E "(apply|edit|add)" | tail -20

# Step 4: Determine root cause
# Option A: Local manual edit (benign)
# Option B: External tool modified config (investigate)
# Option C: Compromised apply (escalate to Critical)

# Step 5: Restore to source-of-truth state
chezmoi apply --force

# Step 6: Verify restoration
chezmoi verify
chezmoi diff  # Should produce no output

# Step 7: Lock critical configs to prevent recurrence
lock-configs
```

### Runbook 4: Tool Compromise (mise/Nix Managed)

**Detection:** Unexpected binary behavior, hash mismatch, or CVE disclosure for a managed tool.

```bash
# Step 1: Quarantine the affected tool
chmod 000 "$(which <tool>)"

# Step 2: Record forensic evidence
sha256sum "$(which <tool>)" > /tmp/quarantine-evidence.txt
ls -la "$(which <tool>)" >> /tmp/quarantine-evidence.txt
file "$(which <tool>)" >> /tmp/quarantine-evidence.txt

# Step 3: Check if the tool executed during shell startup
grep "<tool>" ~/.cache/shell/*
grep "<tool>" ~/.local/share/dotfiles.log

# Step 4: Reinstall from verified source
mise install <tool>@<verified-version> --force
# Or for Nix:
nix profile remove <package>
nix profile install nixpkgs#<package>

# Step 5: Verify replacement binary
sha256sum "$(which <tool>)"

# Step 6: Clear cached eval output that may reference the compromised tool
rm -rf ~/.cache/shell/

# Step 7: Restart shell and verify clean startup
exec "$SHELL" -l
dot health
```

### Runbook 5: CI Pipeline Compromise

**Detection:** Unexpected workflow behavior, modified workflow files, compromised action dependency.

```bash
# Step 1: Disable the affected workflow
gh workflow disable <workflow-name>

# Step 2: Audit recent workflow changes
git log --oneline --all -- '.github/workflows/'
git diff HEAD~10 -- '.github/workflows/'

# Step 3: Check action pinning integrity
grep -r "uses:" .github/workflows/ | grep -v "@"  # Find unpinned actions

# Step 4: Verify no unauthorized secrets access
gh api repos/{owner}/{repo}/actions/runs \
  --jq '.workflow_runs[] | {id, name, conclusion, head_sha}' | head -20

# Step 5: Review workflow permissions
grep -r "permissions:" .github/workflows/

# Step 6: Restore workflows from known-good state
git checkout <known-good-commit> -- .github/workflows/

# Step 7: Re-pin all actions to verified SHA
# Replace tag references with full commit SHA
# Example: actions/checkout@v4 -> actions/checkout@<full-sha>

# Step 8: Re-enable workflow and verify
gh workflow enable <workflow-name>
gh workflow run <workflow-name>
gh run list --workflow=<workflow-name> --limit=1
```

---

## Communication Protocol

### Notification Matrix

| Severity | Notify | Channel | Timeframe |
|----------|--------|---------|-----------|
| Critical | Repository owner, all contributors | GitHub Security Advisory, direct message | Immediate |
| High | Repository owner | GitHub Issue (private), direct message | Within 24 hours |
| Medium | Repository owner | GitHub Issue | Within 5 business days |
| Low | Tracked in backlog | GitHub Issue with `security` label | Next review cycle |

### Escalation Path

```text
1. Incident detected
   └── Automated: CI/hook blocks and logs
   └── Manual: Reporter opens private advisory

2. Triage (within Initial Response SLA)
   └── Classify severity
   └── Assign owner

3. Escalation triggers
   └── No response within SLA -> escalate to next severity level
   └── Scope expansion -> reclassify severity upward
   └── Active exploitation confirmed -> immediate Critical classification
```

### External Notification

| Condition | Action |
|-----------|--------|
| Leaked credentials for third-party service | Notify the service provider to revoke/rotate |
| Compromised upstream dependency | Open issue on upstream repository |
| GitHub Actions vulnerability | Report via GitHub security advisory |

---

## Evidence Preservation

Preserve all forensic evidence before performing eradication or recovery actions.

### Evidence Collection Checklist

| Evidence | Command | Storage |
|----------|---------|---------|
| Dotfiles audit log | `cp ~/.local/share/dotfiles.log /tmp/incident-$(date +%s)/` | Local archive |
| Git reflog | `git reflog > /tmp/incident-$(date +%s)/reflog.txt` | Local archive |
| Git signatures | `git log --show-signature -50 > /tmp/incident-$(date +%s)/signatures.txt` | Local archive |
| Chezmoi state | `chezmoi dump --format=json > /tmp/incident-$(date +%s)/chezmoi-state.json` | Local archive |
| Binary hashes | `sha256sum ~/.local/bin/* > /tmp/incident-$(date +%s)/binary-hashes.txt` | Local archive |
| CI run logs | `gh run view <run-id> --log > /tmp/incident-$(date +%s)/ci-log.txt` | Local archive |
| Shell cache | `cp -r ~/.cache/shell/ /tmp/incident-$(date +%s)/shell-cache/` | Local archive |

### Structured Log Format

Incident evidence is recorded in JSONL format for automated processing:

```bash
# Append structured incident event to log
log_incident() {
  local severity="$1" type="$2" description="$3"
  printf '{"timestamp":"%s","severity":"%s","type":"%s","description":"%s","user":"%s","hostname":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$severity" \
    "$type" \
    "$description" \
    "$(whoami)" \
    "$(hostname)" \
    >> ~/.local/share/incident-log.jsonl
}

# Usage
log_incident "critical" "secrets-exposure" "API key found in commit abc1234"
```

### Retention Policy

| Evidence Type | Retention Period |
|---------------|-----------------|
| Incident logs (JSONL) | 1 year |
| Git reflog snapshots | 90 days |
| Binary hash records | Until next verified release |
| CI run logs | 90 days (GitHub default) |

---

## Recovery Procedures

### Standard Recovery

```bash
# Roll back to a known-good dotfiles state
dot rollback

# Restore specific configuration files
dot restore <target>

# Full re-apply from source of truth
chezmoi init --apply --force

# Verify system health
dot health
dot doctor
```

### Full System Recovery

For incidents requiring complete re-provisioning:

```bash
# Step 1: Export current secrets (if not compromised)
dot secrets export > /tmp/secrets-backup.age

# Step 2: Clear all deployed dotfiles
chezmoi purge

# Step 3: Clear all caches
rm -rf ~/.cache/shell/
rm -rf ~/.cache/chezmoi/

# Step 4: Re-initialize from clean clone
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
git verify-commit HEAD  # Verify signature chain

# Step 5: Re-apply
chezmoi init --apply

# Step 6: Re-import secrets (if exported)
dot secrets import /tmp/secrets-backup.age

# Step 7: Verify
chezmoi verify
dot health
./tests/framework/test_runner.sh
```

### Recovery Verification Checklist

| Check | Command | Expected |
|-------|---------|----------|
| Chezmoi state clean | `chezmoi diff` | No output |
| All managed files present | `chezmoi verify` | Exit code 0 |
| Test suite passes | `./tests/framework/test_runner.sh` | All assertions pass |
| Health dashboard green | `dot health` | No errors |
| Signatures valid | `git log --show-signature -5` | All commits signed |
| Pre-commit hooks active | `pre-commit run --all-files` | All hooks pass |

---

## Post-Incident Review Template

Conduct a review within 5 business days of resolution. Copy the template below into a new file under `docs/security/incidents/`.

````markdown
# Post-Incident Review: [INCIDENT-YYYY-NNN]

## Metadata

| Field | Value |
|-------|-------|
| **Date detected** | YYYY-MM-DD HH:MM UTC |
| **Date resolved** | YYYY-MM-DD HH:MM UTC |
| **Severity** | Critical / High / Medium / Low |
| **Incident type** | Secrets exposure / Supply chain / Drift / Tool compromise / CI compromise |
| **Responder** | @handle |

## Timeline

| Time (UTC) | Event |
|------------|-------|
| HH:MM | Incident detected by [source] |
| HH:MM | Triage completed, classified as [severity] |
| HH:MM | Containment action taken: [description] |
| HH:MM | Root cause identified: [description] |
| HH:MM | Eradication completed |
| HH:MM | Recovery verified |

## Root Cause

[Describe the root cause. Include the specific technical failure, misconfiguration, or external event.]

## Impact

| Dimension | Assessment |
|-----------|------------|
| Data exposed | [What data, if any, was exposed] |
| Systems affected | [Which machines, configs, or pipelines] |
| Duration of exposure | [Time between introduction and remediation] |

## Response Evaluation

| Metric | Target | Actual |
|--------|--------|--------|
| Detection time | Automated / < 1 hour | [actual] |
| Initial response | Per severity SLA | [actual] |
| Resolution | Per severity SLA | [actual] |

## Lessons Learned

### What went well

- [Item]

### What needs improvement

- [Item]

## Action Items

| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| [Preventive measure] | @handle | YYYY-MM-DD | Open |
| [Detection improvement] | @handle | YYYY-MM-DD | Open |
| [Process update] | @handle | YYYY-MM-DD | Open |
````

---

## References

- [NIST SP 800-61 Rev. 2 — Computer Security Incident Handling Guide](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
- [COMPLIANCE.md — Vulnerability Response SLA](COMPLIANCE.md)
- [THREAT_MODEL.md — Attack Surfaces and Mitigations](THREAT_MODEL.md)
- [SECURITY.md — Security Controls and Hardening](SECURITY.md)
- [SLSA Framework](https://slsa.dev/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
