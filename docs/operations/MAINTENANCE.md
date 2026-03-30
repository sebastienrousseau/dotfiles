# Dotfiles Maintenance Runbook

This runbook captures recovery and release maintenance operations for this repository.

## Signed History Recovery (February 19, 2026)

**Purpose:** Recover from strict signature enforcement failures caused by legacy/non-compliant commit history.

**When to use:**

- Pushes are blocked by signature policy on historical commits.
- Merge ancestry contains commits that can't be validated by the current principal/key policy.

**Procedure:**

1. Create a backup ref for current `master`.
2. Build a rewritten signed baseline commit from the current tree.
3. Push the rewritten branch to remote.
4. Temporarily allow force-push on `master` protections/rulesets.
5. Force-update `master` to the rewritten signed baseline.
6. Disable force-push again immediately.
7. Re-run CI and verify required checks are green.
8. Repoint the release tag/target as needed.

**Verification commands:**

```bash
git verify-commit HEAD
gh run list --workflow ci.yml --branch master --limit 1
gh release view v0.2.498 --json tagName,targetCommitish,url
```

## Release Closeout Checklist

For every release update:

1. `master` branch is clean and synced.
2. CI is green on the release commit.
3. Annotated release tag points to the intended commit.
4. GitHub release target is correct (`master` or explicit commit).
5. Branch protections/rulesets are restored to strict state.
6. Local apply has completed:

```bash
CHEZMOI_SOURCE_DIR="$HOME/.dotfiles" ./dot_local/bin/executable_dot apply
```

## Security Scan Guardrails

We prevent gitleaks historical-scan regressions with:

- Shallow checkout (`fetch-depth: 1`, `fetch-tags: false`) in gitleaks jobs.
- A workflow-dispatch guard script: `scripts/ci/guard-gitleaks-checkout.sh`.

**Manual verification:**

```bash
bash scripts/ci/guard-gitleaks-checkout.sh
```
