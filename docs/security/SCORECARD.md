---
render_with_liquid: false
---

# OpenSSF Scorecard

This page records the current OpenSSF Scorecard posture for this
repository, the known gaps, and the remediation roadmap. The badge in
the README links to the live result; this page is the maintained
narrative behind it.

## Live score

<!-- BEGIN scorecard-snapshot (auto-generated, do not edit by hand) -->
Aggregate score **8.3 / 10** at 2026-10-29T07:04:00Z.

| Check | Score | Reason |
|---|---:|---|
| Binary-Artifacts | 10 | no binaries found in the repo |
| Branch-Protection | 3 | branch protection is not maximal on development and all release branches |
| CI-Tests | 10 | 30 out of 30 merged PRs checked by a CI test -- score normalized to 10 |
| CII-Best-Practices | 5 | badge detected: Passing |
| Code-Review | 0 | Found 0/27 approved changesets -- score normalized to 0 |
| Contributors | 0 | project has 0 contributing companies or organizations -- score normalized to 0 |
| Dangerous-Workflow | 10 | no dangerous workflow patterns detected |
| Dependency-Update-Tool | 10 | update tool detected |
| Fuzzing | 10 | project is fuzzed |
| License | 10 | license file detected |
| Maintained | 10 | 30 commit(s) and 2 issue activity found in the last 90 days -- score normalized to 10 |
| Packaging | 10 | packaging workflow detected |
| Pinned-Dependencies | 9 | dependency not pinned by hash detected -- score normalized to 9 |
| SAST | 9 | SAST tool detected but not run on all commits |
| Security-Policy | 10 | security policy file detected |
| Signed-Releases | 10 | 5 out of the last 5 releases have a total of 10 signed artifacts. |
| Token-Permissions | 10 | GitHub workflow tokens follow principle of least privilege |
| Vulnerabilities | 10 | 0 existing vulnerabilities detected |

*Refresh: `scripts/qa/scorecard-snapshot.sh` · Monitoring: `.github/workflows/scorecard.yml`.*
<!-- END scorecard-snapshot -->

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/sebastienrousseau/dotfiles/badge)](https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/dotfiles)

The badge above is regenerated every Monday at 06:00 UTC and on every
push to `main` by `.github/workflows/scorecard.yml`. The SARIF
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

## Per-check posture (snapshot, main HEAD)

The checks below come from OpenSSF Scorecard's published rubric. Tick
marks reflect this repo's posture at the time of writing — the
*live* badge is authoritative if these diverge.

| Check | Status | Notes |
|---|---|---|
| Branch-Protection | ⚠ | Classic branch protection on `main` requires signed commits, linear history, conversation resolution and five status checks, enforced for admins, with 0 required approvals (see [`.github/BRANCH_PROTECTION.md`](../../.github/BRANCH_PROTECTION.md)). Scorecard scores it below maximal, chiefly because no approving review is required. `.github/rulesets/main.json` is not applied. |
| Code-Review | ⚠ | Single-maintainer repo; PRs are self-merged after CI. Scorecard scores 0 here by design (see `Open findings` below). |
| Signed-Commits | ✓ | Enforced by pre-push hook (`scripts/git-hooks/pre-push`) and at-push by branch protection (#853 + #857). |
| Dependency-Update-Tool | ✓ | Dependabot configured for github-actions / npm / docker / devcontainers / uv / gomod / cargo. |
| Fuzzing | ✓ | Native Go fuzz harnesses under `fuzz/` and in the Go modules under `defaults/dot_local/share/`, run by `.github/workflows/fuzz.yml`, plus the ClusterFuzzLite setup in `.clusterfuzzlite/` and `fuzz/oss-fuzz/`. The shell `install.sh` harness lives under `fuzz/install/` (#881). See [FUZZING.md](FUZZING.md). |
| License | ✓ | Dual Apache-2.0 / MIT at repo root (`LICENSE-APACHE`, `LICENSE-MIT`). |
| Maintained | ✓ | Active commit cadence; the [README](https://github.com/sebastienrousseau/dotfiles/blob/main/README.md) lists the current `dotfiles_version`. |
| Pinned-Dependencies | ⚠ | Closed 8 of 14 findings this cycle (every Dockerfile base + every workflow action + 2 `curl \| sh` installers + the `npm install -g npm` upgrade step). The residual findings are dismissed by design (see `Open findings`). |
| SAST | ✓ | CodeQL (`.github/workflows/codeql.yml`) + Checkov + Grype. |
| SBOM | ✓ | Generated per PR by `sbom-diff.yml` and per release by `security-release.yml`. |
| Security-Policy | ✓ | `SECURITY.md` + this page + `docs/security/THREAT_MODEL.md`. |
| Token-Permissions | ✓ | Top-level `permissions:` blocks restricted to `contents: read`. `write` scopes scoped to the jobs that need them (#886). |
| Vulnerabilities | ✓ | Grype gate hard-fails on `high` / `critical` on `main` (#852). |
| Webhooks | n/a | No external webhooks configured. |
| CI-Tests | ✓ | Linux + macOS (Apple Silicon) matrix; Windows when shell or Windows files change. |
| CII-Best-Practices | ✓ | OpenSSF Best Practices badge at passing tier. |
| Dangerous-Workflow | ✓ | No `pull_request_target` with checkout-PR-code anti-pattern. |
| Packaging | ✓ | `npm publish --provenance` via OIDC (`.github/workflows/npm-publish.yml`); `policy-bundle-release.yml` for the policy artifact. |
| Signed-Releases | ✓ | SLSA provenance (`.intoto.jsonl`) and Cosign keyless signatures (`.sig` + `.pem`) attached via `security-release.yml` (#876). |

## Open findings

Scorecard raises these as alerts at
<https://github.com/sebastienrousseau/dotfiles/security/code-scanning>.
Each row gives the dismissal **reason** and the exact **comment text**
to paste when triaging. Every alert listed here has been dismissed with
that reason; when Scorecard re-raises one (for example after the line
moves), dismiss it again with the same text.

### Bucket 1 — Dismiss in the UI

Scorecard flags every `npm install`, `pip install`, `go install`, and
`curl | sh` invocation under the `Pinned-Dependencies` check. The rows
below either belong to user-facing tooling that installs the latest
release on purpose or are false positives in Scorecard's regex.

| Path | Reason | Comment to paste |
|---|---|---|
| `defaults/.chezmoitemplates/aliases/legal/legal.aliases.sh:64` | **Won't fix** | User-facing `gen-notice` alias runs `go install github.com/google/go-licenses@latest` in a throwaway container to build a NOTICE file. Pinning by SHA would require users to update the alias manually on every upstream change. Intentional. |
| `lib/dot/upgrade.sh:144` | **Won't fix** | `npm update -g` in `dot update --globals`, which the user asks for to bring global packages to their latest release. Pinning defeats it. Intentional. |
| `plugins/tool/libexec/tool.sh:112` | **False positive** | `npm install --package-lock-only --ignore-scripts --silent` generates a lockfile and does NOT fetch packages. Scorecard's regex matches `npm install` blindly; this invocation has no supply-chain surface. |
| `install/provision/run_onchange_10-linux-packages.sh.tmpl:383` | **Won't fix** | Already exact-version-pins `aider-chat==0.86.2`. Scorecard wants sha256-hash pinning, which would require a ~2,700-line lockfile covering all 108 transitive deps and re-generated on every aider release — disproportionate maintenance for a single optional provisioning install. |

### Bucket 2 — Architectural (1 item)

| Alert | Why architectural |
|---|---|
| `CodeReviewID` (high) — score 0 | Scorecard requires every merged PR to record an approval review by a different GitHub user than the author. This repo is single-maintainer; PRs are self-merged after CI. The fix path is either (a) onboard a co-maintainer who reviews PRs before merge, or (b) accept the finding. Dismiss as **Won't fix** with comment: "Single-maintainer project — no second reviewer available. CI gates (five required status checks per PR, the Merge Gate among them) substitute for human review." |

## Closed this cycle

| Date | Score | Alerts open | Change |
|---|---|---|---|
| 2026-05-14 | 6.5 | 28 | First clean publish after fixing the scorecard.yml `uses:`-only restriction (#885). Findings had been hidden by publish-step 400s until then. |
| 2026-05-14 | 6.5 | 11 | Closed 17 of 28: 10× TokenPermissions (#886), 6× Dockerfile bases (#886), 1× gitleaks fixture (#884). |
| 2026-05-14 | 6.5 | 9 | Closed 2× `curl \| sh` installers (#888). |
| 2026-05-14 | 6.5 | 8 | Closed 1× `npm install -g npm@…` via Node 24 bump (#889). |
| 2026-05-17 | 7.6 | 7 | v0.2.502 released; Cosign keyless signing live (#876 implementation landed in `security-release.yml` sbom job). |
| 2026-05-17 | 7.6 | 6 | SLSA Release Attestation pipeline unblocked (PR #894 — 6 prior releases had failed identically). v0.2.502 backfilled with `.intoto.jsonl` + `.sig` + `.pem` triplet. `Signed-Releases` should bump from 3 to ~10 on next Scorecard re-scrape. |
| 2026-05-17 | 7.6 | — | Added `MAINTAINERS.md` + `GOVERNANCE.md` at repo root. Provides the formal context for the `Code-Review` 0/30 score (solo maintainer) and unblocks the CII Best Practices badge application. |

## Open work

- **`harden-runner` block-mode adoption (#878)**: should tighten the `Token-Permissions` check further.
- **`Branch-Protection` 3/10**: the live score is held down by the 0-approval review setting on a single-maintainer repo (see Bucket 2).

### Enabling Branch-Protection + Webhooks checks in the workflow (one-time PAT setup)

The repository's own `scorecard.yml` run needs a fine-grained Personal
Access Token with `Administration: read` scope to read the
`Branch-Protection` and `Webhooks` checks; without it both return `-1`
("internal error") in that run. (The public snapshot above comes from
the Scorecard API, which scores `Branch-Protection` on its own.) The
workflow already wires this up, and the `SCORECARD_TOKEN` secret is not
set today.

Steps (one-time, repo owner):

1. Go to <https://github.com/settings/personal-access-tokens/new>
2. **Resource owner**: `sebastienrousseau` · **Repository access**: only `sebastienrousseau/dotfiles`
3. **Repository permissions** → `Administration: read-only` and `Metadata: read-only`
4. **Expiration**: 1 year (set a calendar reminder to rotate; document the rotation in this file when done)
5. Generate the token, copy it once
6. Add as a secret named `SCORECARD_TOKEN` at <https://github.com/sebastienrousseau/dotfiles/settings/secrets/actions/new>
7. Next Scorecard run (manual via `gh workflow run scorecard.yml` or weekly cron) picks it up automatically
8. Expected effect: `Branch-Protection` `-1` → 10/10 if all rules are correctly configured; `Webhooks` `-1` → 10/10 (no webhooks present).

The PAT secret is **optional**. When absent, the workflow falls back
to `${{ github.token }}` and Scorecard continues to run, only with
those two checks at `-1`. Adding the PAT cannot reduce any other check's
score — it's a strict improvement.

## Exceptions

| Check | Expiry | Rationale |
|---|---|---|
| *(none currently)* | *—* | *—* |

If you add an exception, include the check name, an expiry date
(don't allow indefinite), and the rationale. Re-evaluate every quarter.

## Refreshing this document

```bash
# Re-count open alerts:
gh api 'repos/sebastienrousseau/dotfiles/code-scanning/alerts?state=open&per_page=50' \
  --jq '[.[].rule.id] | group_by(.) | map({rule: .[0], count: length})'

# Trigger Scorecard manually:
gh workflow run scorecard.yml --ref main
```

If a new category appears, add a row to the matching bucket. If a
remediation closes one of the rows above, delete the row.

## References

- `.github/workflows/scorecard.yml` — the scanner workflow (split into
  `analysis` + `track-regression` jobs per #885).
- [Scorecard project](https://github.com/ossf/scorecard).
- [Scorecard checks reference](https://github.com/ossf/scorecard/blob/main/docs/checks.md).
- Tracking issue [#869](https://github.com/sebastienrousseau/dotfiles/issues/869).
