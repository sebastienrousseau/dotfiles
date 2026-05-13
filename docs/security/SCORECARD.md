---
render_with_liquid: false
---

# OpenSSF Scorecard

This page records the current OpenSSF Scorecard posture for this
repository, the known gaps, and the remediation roadmap. The badge in
the README links to the live result; this page is the maintained
narrative behind it.

## Live score

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/sebastienrousseau/dotfiles/badge)](https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/dotfiles)

The badge above is regenerated every Monday at 06:00 UTC and on every
push to `master` by `.github/workflows/scorecard.yml`. The SARIF
result is uploaded to GitHub Code Scanning (Security tab) and
retained as a 30-day workflow artifact.

## Threshold policy

| Score | Action |
|---|---|
| ≥ 8.0 | Healthy. Keep doing what we're doing. |
| 7.0 – 7.9 | Acceptable. Tracked. |
| < 7.0 | Regression — the workflow auto-opens a tracking issue labelled `type:security + priority:high`. |

Regressions are triaged within one Monday cycle: identify the check
that dropped, either remediate or file an exception entry below with
a rationale and an expiry date.

## Per-check posture (snapshot)

The checks below come from OpenSSF Scorecard's published rubric. Tick
marks reflect this repo's posture at the time of writing — the
*live* badge is authoritative if these diverge.

| Check | Status | Notes |
|---|---|---|
| Branch-Protection | ✓ | `master` requires signed commits, linear history, required checks. Codified at `.github/rulesets/master.json` and `.github/branch-protection-config.json`. |
| Code-Review | ✓ | Every PR requires at least one approval; CODEOWNERS in place. |
| Signed-Commits | ✓ | Enforced by pre-push hook (`scripts/git-hooks/pre-push`) and at-push by branch protection (#853 + #857). |
| Dependency-Update-Tool | ✓ | Dependabot configured for github-actions / npm / docker / devcontainers / uv. |
| Fuzzing | ⚠ | `install.sh` fuzz harness lives under `tests/fuzz/` (closes #881). Coverage is the script's CLI surface plus chaos input fixtures — not full corpus fuzzing yet. |
| License | ✓ | Apache-2.0 at repo root. |
| Maintained | ✓ | Active commit cadence; the [README](../../README.md) lists the current `dotfiles_version` (v0.2.501). |
| Pinned-Dependencies | ✓ | Every workflow action is pinned to a 40-char commit SHA; the lint rule under `actionlint` enforces this on PR. |
| SAST | ✓ | CodeQL (`.github/workflows/codeql.yml`) + Checkov + Grype. |
| SBOM | ✓ | Generated per PR by `sbom-diff.yml` and per release by `security-release.yml`. |
| Security-Policy | ✓ | `.github/SECURITY.md` + this page + `docs/security/THREAT_MODEL.md`. |
| Token-Permissions | ✓ | Workflows use least-privilege `permissions:` blocks. `harden-runner` adoption (#878) tightens this further. |
| Vulnerabilities | ✓ | Grype gate hard-fails on `high` / `critical` on `master` (#852). |
| Webhooks | n/a | No external webhooks configured. |
| CI-Tests | ✓ | Comprehensive CI matrix (Linux + macOS Intel + Apple Silicon, optional Windows). |
| CII-Best-Practices | ☐ | Not applied yet — see "Open work" below. |
| Dangerous-Workflow | ✓ | No `pull_request_target` with checkout-PR-code anti-pattern. |
| Packaging | ✓ | `npm publish --provenance` via OIDC (`.github/workflows/npm-publish.yml`); `policy-bundle-release.yml` for the policy artifact. |

## Open work

- Apply for the [OpenSSF Best Practices badge (CII)](https://www.bestpractices.dev/) and embed it next to the Scorecard badge. (Maintainer action — needs the project to register with the BestPractices.dev site.)
- Once `harden-runner` is in `block` mode across all jobs (#878), the **Token-Permissions** check should hit its maximum.
- Once Cosign keyless signing is wired into the release pipeline (#876), the **Signed-Releases** check should hit its maximum.

## Exceptions

| Check | Expiry | Rationale |
|---|---|---|
| _(none currently)_ | _—_ | _—_ |

If you add an exception, include the check name, an expiry date
(don't allow indefinite), and the rationale. Re-evaluate every quarter.

## References

- `.github/workflows/scorecard.yml` — the scanner.
- [Scorecard project](https://github.com/ossf/scorecard).
- [Scorecard checks reference](https://github.com/ossf/scorecard/blob/main/docs/checks.md).
- Issue [#869](https://github.com/sebastienrousseau/dotfiles/issues/869).
