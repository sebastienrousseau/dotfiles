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

## Per-check posture (snapshot, master HEAD)

The checks below come from OpenSSF Scorecard's published rubric. Tick
marks reflect this repo's posture at the time of writing — the
*live* badge is authoritative if these diverge.

| Check | Status | Notes |
|---|---|---|
| Branch-Protection | ⚠ | `master` requires signed commits, linear history, required checks (`.github/rulesets/master.json`). Scorecard can't read classic protection rules without a fine-grained PAT, so this check reports as `-1` ("internal error"). |
| Code-Review | ⚠ | Single-maintainer repo; PRs are self-merged after CI. Scorecard scores 0/30 here by design — see `Open findings` below. |
| Signed-Commits | ✓ | Enforced by pre-push hook (`scripts/git-hooks/pre-push`) and at-push by branch protection (#853 + #857). |
| Dependency-Update-Tool | ✓ | Dependabot configured for github-actions / npm / docker / devcontainers / uv. |
| Fuzzing | ⚠ | `install.sh` fuzz harness lives under `tests/fuzz/` (closes #881), but it's shell-based and Scorecard's heuristic only recognizes OSS-Fuzz / ClusterFuzzLite / native Go fuzz / libFuzzer / Atheris. None support shell. Property tests under `tests/unit/functions/test_property_*.sh` cover the closest equivalent surface. |
| License | ✓ | MIT at repo root (`LICENSE`). |
| Maintained | ✓ | Active commit cadence; the [README](../../README.md) lists the current `dotfiles_version`. |
| Pinned-Dependencies | ⚠ | Closed 8 of 14 findings this cycle (every Dockerfile base + every workflow action + 2 `curl \| sh` installers + the `npm install -g npm` upgrade step). 5 residual findings stay open by design — see `Open findings`. |
| SAST | ✓ | CodeQL (`.github/workflows/codeql.yml`) + Checkov + Grype. |
| SBOM | ✓ | Generated per PR by `sbom-diff.yml` and per release by `security-release.yml`. |
| Security-Policy | ✓ | `.github/SECURITY.md` + this page + `docs/security/THREAT_MODEL.md`. |
| Token-Permissions | ✓ | Top-level `permissions:` blocks restricted to `contents: read`. `write` scopes scoped to the jobs that need them (#886). |
| Vulnerabilities | ✓ | Grype gate hard-fails on `high` / `critical` on `master` (#852). |
| Webhooks | n/a | No external webhooks configured. |
| CI-Tests | ✓ | Linux + macOS Intel + Apple Silicon matrix; optional Windows. |
| CII-Best-Practices | ☐ | Not applied yet — see `Open work` below. |
| Dangerous-Workflow | ✓ | No `pull_request_target` with checkout-PR-code anti-pattern. |
| Packaging | ✓ | `npm publish --provenance` via OIDC (`.github/workflows/npm-publish.yml`); `policy-bundle-release.yml` for the policy artifact. |
| Signed-Releases | ⚠ | SLSA provenance + minisig attached via `security-release.yml`; Cosign keyless signing tracked at #876. |

## Open findings

The eight items below are surfaced as alerts at
<https://github.com/sebastienrousseau/dotfiles/security/code-scanning>.
Each row gives the dismissal **reason** and the exact **comment text**
to paste when triaging.

### Bucket 1 — Dismiss in the UI (5 items)

Scorecard flags every `npm install`, `pip install`, `go install`, and
`curl | sh` invocation under the `Pinned-Dependencies` check. The five
below either belong to user-facing "update everything" aliases or are
false positives in Scorecard's regex.

| Path | Reason | Comment to paste |
|---|---|---|
| `.chezmoitemplates/aliases/legal/legal.aliases.sh:64` | **Won't fix** | User-facing convenience alias — `go install <fortune-style joke command>@latest`. Pinning by SHA would require users to update the alias manually on every upstream change. Intentional. |
| `.chezmoitemplates/aliases/update/update.aliases.sh:173` | **Won't fix** | User-facing convenience alias — bulk-update wrapper around `npm`. The alias's purpose is to update everything; pinning defeats it. Intentional. |
| `dot_local/bin/executable_update:99` | **Won't fix** | `dot_local/bin/executable_update` is the user-invoked "update everything" command. The literal point of `npm update -g` is to update to whatever's latest. Pinning defeats it. Intentional. |
| `scripts/dot/commands/tools.sh:121` | **False positive** | `npm install --package-lock-only --ignore-scripts --silent` generates a lockfile and does NOT fetch packages. Scorecard's regex matches `npm install` blindly; this invocation has no supply-chain surface. |
| `install/provision/run_onchange_10-linux-packages.sh.tmpl:369` | **Won't fix** | Already exact-version-pins `aider-chat==0.86.2`. Scorecard wants sha256-hash pinning, which would require a ~2,700-line lockfile covering all 108 transitive deps and re-generated on every aider release — disproportionate maintenance for a single optional provisioning install. |

### Bucket 2 — Architectural (1 item)

| Alert | Why architectural |
|---|---|
| `CodeReviewID` (high) — score 0 | Scorecard requires every merged PR to record an approval review by a different GitHub user than the author. This repo is single-maintainer; PRs are self-merged after CI. The fix path is either (a) onboard a co-maintainer who reviews PRs before merge, or (b) accept the finding. Dismiss as **Won't fix** with comment: "Single-maintainer project — no second reviewer available. CI gates (47 required checks per PR) substitute for human review." |

### Bucket 3 — External action (2 items)

| Alert | Action |
|---|---|
| `FuzzingID` (medium) | Dismiss as **Won't fix** with comment: "Repo is bash + Go-template + Lua. ClusterFuzzLite / OSS-Fuzz / native Go fuzz / libFuzzer / Atheris (the frameworks Scorecard recognises) all target compiled languages, none support shell. The `tests/fuzz/fuzz_install.sh` harness + property tests under `tests/unit/functions/test_property_*.sh` cover the equivalent surface." |
| `CIIBestPracticesID` (low) | Apply at <https://www.bestpractices.dev/projects/new>. ~67 self-attested questions, free, 1-2 hours. After silver-tier approval, paste the badge into `README.md` next to the existing Scorecard badge. Most criteria already met (signed commits, CI, security policy, license). |

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

- **Apply for the OpenSSF Best Practices Badge** — see Bucket 3 above. All passing-tier criteria are now met (signed commits, CI, security policy, MIT license, MAINTAINERS.md, GOVERNANCE.md, RFC process documented).
- **Re-trigger Scorecard after SLSA backfill propagates** — expected `Signed-Releases` 3 → 10.
- **`harden-runner` block-mode adoption (#878)** — should tighten the `Token-Permissions` check further.
- **Investigate `License` 9/10 false-positive** — repo is MIT (SPDX-compliant), Scorecard's penalty should not apply.
- **Investigate `Branch-Protection` `-1`** — scanner internal error; manually verify with `gh api repos/:owner/:repo/branches/master/protection` and document.

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
gh workflow run scorecard.yml --ref master
```

If a new category appears, add a row to the matching bucket. If a
remediation closes one of the rows above, delete the row.

## References

- `.github/workflows/scorecard.yml` — the scanner workflow (split into
  `analysis` + `track-regression` jobs per #885).
- [Scorecard project](https://github.com/ossf/scorecard).
- [Scorecard checks reference](https://github.com/ossf/scorecard/blob/main/docs/checks.md).
- Tracking issue [#869](https://github.com/sebastienrousseau/dotfiles/issues/869).
