---
render_with_liquid: false
---

# CI Dependency Pinning Policy

Every external dependency the CI pipeline consumes must be pinned by
40-hex commit SHA. The policy applies to:

1. **Third-party actions** — `uses: owner/action@<sha>` (already enforced via Scorecard's `Pinned-Dependencies` check at score ≥ 9).
2. **Reusable workflows in this repo** — `uses: sebastienrousseau/dotfiles/.github/workflows/reusable-X.yml@<sha>` (added with [#855](https://github.com/sebastienrousseau/dotfiles/issues/855); enforced by `tools/ci/lint-reusable-pins.sh`).
3. **Container base images** — `FROM image:tag@sha256:<digest>` (closed by [#886](https://github.com/sebastienrousseau/dotfiles/pull/886)).
4. **Release binaries downloaded at build time** — `curl … && echo "<sha256> ..." | sha256sum -c` (closed by [#888](https://github.com/sebastienrousseau/dotfiles/pull/888)).

## Why SHA-pin reusable workflows

When `ci.yml` calls a reusable via `./.github/workflows/reusable-X.yml`,
GitHub resolves the reusable from the **same ref as the calling
workflow at run time**. For an in-repo PR that's the PR's branch —
fine. The risk is the inverse: a malicious push to `master` (or any
ref the calling workflow might resolve from) can swap reusable
content under a CI run, with no audit trail in the PR diff.

Pinning to a 40-hex SHA freezes the reusable's content at the
pinned commit. To swap the reusable, you have to bump every call
site — visible in the PR diff, reviewable, revertible.

## Acceptable forms

```yaml
# Acceptable — full SHA pin.
uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@b0615f8fb5c0f3826f58904a5567eff11b6c500e # master
```

The trailing comment is a human-readable hint at what the SHA
represented when it was pinned (typically `master`, sometimes a tag
like `v0.2.501`). The hint is documentation only — the SHA is what
GitHub uses.

## Rejected forms

```yaml
# Rejected — relative path is a mutable ref.
uses: ./.github/workflows/reusable-shell-lint.yml

# Rejected — branch ref is mutable.
uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@master

# Rejected — tag ref is mutable (tags can be moved).
uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@v0.2.501
```

The `lint-reusable-pins` job in `ci.yml` runs `tools/ci/lint-reusable-pins.sh`
on every workflow change. The lint fails the build on any of the
rejected forms above.

## Refreshing pinned SHAs

Reusable workflows in this repo are the only same-repo dependency
Dependabot doesn't auto-bump. Refresh manually after a change to a
reusable:

```sh
# 1. Land the change to the reusable on master via a PR.
# 2. After merge, capture the new master SHA:
git fetch origin master
PIN=$(git rev-parse origin/master)
echo "$PIN"

# 3. Bump every call site:
find .github/workflows -name '*.yml' -exec sed -i.bak -E \
  "s|(/reusable-[a-z0-9-]+\.yml@)[0-9a-f]{40}|\\1${PIN}|g" {} +
rm -f .github/workflows/*.bak

# 4. Verify the lint still passes:
bash tools/ci/lint-reusable-pins.sh

# 5. Land the bump on a follow-up PR with a single-purpose commit:
git commit -am "chore(ci): bump reusable-workflow pins to ${PIN:0:10}"
```

We treat the manual bump as **deliberate**, not a chore — it forces
a reviewer to confirm the new reusable content is intentional.

## Dependabot

Dependabot's `github-actions` ecosystem **does not** support same-repo
reusable workflow SHA bumps as of May 2026 — it only updates
references to external actions. Same-repo reusables are tracked
manually via the recipe above. The Dependabot config in
`.github/dependabot.yml` covers the external dimension; this
document covers the in-repo one.

If GitHub ships native Dependabot support for reusable workflows,
delete this section and switch to `package-ecosystem: github-actions`
with `directory: /.github/workflows`. Track on
[github/feedback#10539](https://github.com/orgs/community/discussions/10539).

## Negative test

`tests/unit/ci/test_reusable_pin_lint.sh` deliberately drops an
unpinned reusable reference into a sandboxed workflow tree and
asserts that `lint-reusable-pins.sh` exits non-zero with the
expected error message. The test runs as part of the standard
test suite — a regression in the lint catches at PR time, not at
merge time.

## See also

- [#855](https://github.com/sebastienrousseau/dotfiles/issues/855) — original tracking issue.
- `tools/ci/lint-reusable-pins.sh` — the enforcement script.
- `tests/unit/ci/test_reusable_pin_lint.sh` — the negative test.
- [GitHub: pinning actions to a full-length commit SHA](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions).
