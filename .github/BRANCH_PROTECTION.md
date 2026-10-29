# Branch Protection Configuration

This document describes the protection that GitHub enforces on `main`
today. The live repository settings are the source of truth; read them
with:

```bash
gh api repos/sebastienrousseau/dotfiles/branches/main/protection
gh api repos/sebastienrousseau/dotfiles/rulesets
```

Two mechanisms apply to `main`: classic branch protection, which
carries the required checks, signatures and review rules, and one
repository ruleset, which blocks deletion and force-push.

## Required Status Checks

Classic branch protection requires these five status checks, with
**Require branches to be up to date before merging** (`strict`) on.
GitHub matches a check by its job `name:`, not its job id.

| Required check | Workflow | Job id | What it gates |
|---|---|---|---|
| `Merge Gate` | `ci-enforced.yml` | `merge-gate` | Fails if any job it needs failed or was cancelled (see below) |
| `Reliability Summary` | `reliability-gate.yml` | `reliability-summary` | Reliability audit on Ubuntu and two macOS runners, plus the examples, feature-matrix, WSL and PowerShell contracts |
| `Pre-Commit` | `pre-commit.yml` | `pre-commit` | The repository's pre-commit hooks that run deterministically in one runner (YAML, Markdown, spelling, GitHub Actions lint) |
| `Check sign-off` | `dco.yml` | `dco` | Every PR commit carries a `Signed-off-by:` trailer |
| `Verify PR description signature` | `pr-signature.yml` | `check-signature` | The PR body carries the two required signature lines (skipped for Dependabot and `github-actions[bot]` PRs) |

`Merge Gate` runs with `if: always()` so that a failed dependency fails
the gate instead of skipping it (GitHub counts a skipped required check
as passed). It needs these `ci-enforced.yml` jobs:

- `lint-shell`, `lint-lua`, `lint-nix`, `lint-copyright`
- `security-secrets`, `security-dependency-audit`,
  `security-infrastructure`, `security-policy-script`
- `test-matrix`, `test-unit`, `test-mutation`
- `lint-tests`, `lint-install-pins`, `lint-complexity`

Other workflows (for example `compliance-guard.yml`,
`security-enhanced.yml` and CodeQL) run on PRs and show their results,
but they are not required checks and do not block a merge on their own.

## Branch Protection Settings

Live classic protection on `main`:

| Setting | Value |
|---|---|
| Required status checks | The five above, `strict: true` |
| Required approving reviews | 0 (a PR is still required; stale reviews are dismissed) |
| Code owner review | Not required |
| Require signed commits | On |
| Require linear history | On |
| Require conversation resolution | On |
| Enforce for administrators | On |
| Allow force pushes | Off |
| Allow deletions | Off |

Repository ruleset "Protect default branch (no force-push, no
deletion)" (id `17924858`, active) targets the default branch with two
rules, `deletion` and `non_fast_forward`. Its bypass list holds the
repository admin role.

## Configuration files in this repository

`.github/rulesets/main.json` and `.github/branch-protection-config.json`
describe a stricter target (one code-owner approval, last-push
approval, and fifteen required checks). **Neither is applied** to the
repository, so neither describes what GitHub enforces. Two of their
fifteen check contexts also name no job in any workflow:
`Type Check / Strict Mode`, and `Test / Integration` (the job is named
`Test / Integration (Docker)`). Applying either file as it stands would
leave those two checks pending forever and block every merge.

## Shell lint policy

The `Lint / Shell (Zero Warnings)` job behind `Merge Gate` runs
shellcheck at `error` severity, excluding SC1091, SC2030 and SC2031,
and runs shfmt over `scripts/**/*.sh`, `install.sh` and
`defaults/.chezmoitemplates/**/*.sh`.

## Bypass Procedures

`enforce_admins` is on, so an administrator cannot merge past a failing
required check or an unsigned commit without first changing the
protection settings. That change is visible in the repository's audit
log.

- **NEVER** bypass for convenience
- **NEVER** use `--no-verify` git flags
- **NEVER** disable required status checks permanently

## Verify protection

```bash
gh api repos/sebastienrousseau/dotfiles/branches/main/protection \
  --jq '.required_status_checks.contexts[]'
```
