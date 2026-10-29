# Contributing

Keep changes small. Keep them signed. Keep them tested.

## Before opening a pull request

Run:

```bash
make test
bash scripts/git-hooks/pre-push
```

Use a signed, signed-off commit:

```bash
git commit -S -s -m "fix: concise summary"
```

`-S` adds the cryptographic signature; `-s` adds the DCO `Signed-off-by`
line (see below). Signed commits are **enforced** at two layers: the local
pre-push hook (`scripts/git-hooks/pre-push`, installed by
`scripts/git-hooks/install.sh`) and `main`'s branch protection, which requires
signed commits. An unsigned commit cannot reach `main`. Full SSH and GPG setup recipes plus verification
commands live in [`docs/security/COMMIT_SIGNING.md`](docs/security/COMMIT_SIGNING.md).

### Developer Certificate of Origin (DCO)

Every commit must carry a `Signed-off-by` line certifying that you wrote the
change (or otherwise have the right to submit it under the project's licence),
per the [Developer Certificate of Origin](DCO) 1.1. Add it automatically with
`git commit -s` (combine with `-S` to cryptographically sign as well). The
**DCO** GitHub workflow checks every commit in a pull request; bring an existing
branch into compliance with `git rebase --signoff <base>`.

The pre-push audit is **mandatory by default**. If you need to bypass
it for a single push (rare, almost never on `main`), see
[`docs/security/AUDIT_BYPASS.md`](docs/security/AUDIT_BYPASS.md). The
legacy `DOTFILES_SKIP_PRE_PUSH_AUDIT=1` variable is no longer honored.

## Pre-commit hooks

The repo ships a `pre-commit` configuration that mirrors CI
(`config/pre-commit-config.yaml`, linked from `.pre-commit-config.yaml`).
`pre-commit install` refuses to run while any `core.hooksPath` is set, and
these dotfiles set a global one, so install once per clone with the global
config hidden:

```bash
pip install --user pre-commit          # or: brew install pre-commit
GIT_CONFIG_GLOBAL=/dev/null pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push -f
```

Installing the `pre-push` type replaces the hand-written
`.git/hooks/pre-push` from `scripts/git-hooks/install.sh` (signature check
and reliability audit); see the note in `config/pre-commit-config.yaml`.

Run every hook against every file (do this after fresh-cloning, after
big merges, or when CI surfaces a hook you don't have locally):

```bash
pre-commit run --all-files --config config/pre-commit-config.yaml
```

Hooks in this config (shellcheck, shfmt, hadolint, gitleaks,
detect-secrets, checkov, conventional-commit linter, typos-cli,
actionlint, **luacheck**, **stylua**, plus repo-local custom hooks)
run on commit by default. The `luacheck` hook is pinned to the version
CI uses (v1.2.0). The `stylua` hook is not yet: pre-commit pins v2.4.1
while `ci.yml` and `ci-enforced.yml` pass `stylua_version: "0.20.0"`.
Keep the pins in step when you bump one (see [`config/pre-commit-config.yaml`](config/pre-commit-config.yaml)
and [`.github/workflows/reusable-lua-lint.yml`](.github/workflows/reusable-lua-lint.yml)).

## Pull request checklist

- Use signed commits
- Keep the branch focused
- Update docs with code changes
- Include the commands that passed
- Use a clear title

## Branch names

Examples:

- `feat/new-command`
- `fix/fish-alias-cache`
- `docs/readme-cleanup`

## Long-lived branches

A branch that outlives a single pull request has to be merged from `main` on a
cadence, not "before it lands". The cost of reconciling is not linear in time —
it compounds, because both lines keep editing the same files.

The long-lived `feat/v0.2.5xx` release line is the worked example. PR #1031 wrote the plan down in August:
land it *after* a rebase absorbs the 84 `main` fixes it was behind. That rebase
did not happen. By September it was **140 behind and 225 ahead**, and merging
`main` into it produced **322 conflict hunks across 180 files**, 63 of them
whole-file add/add decisions with no consistent winner — `main`'s copy was
larger in 48 and `feat`'s in 14, so no blanket rule could resolve them safely.

The `Branch Drift Guard` workflow fails once a tracked branch is more than
40 commits behind `main` (roughly a fortnight here). Its weekly run still
targets `feat/v0.2.503`, which has since been deleted, so it reports nothing
to guard; run it by hand (`workflow_dispatch`) with the `branch` input for a
live long-lived branch. If it fails:

```sh
git checkout <the long-lived branch>
git merge origin/main      # resolve, then push
```

`rerere` is enabled in the git config these dotfiles deploy
(`defaults/dot_gitconfig.tmpl`; elsewhere, `git config rerere.enabled true`),
so a conflict you resolve once is replayed
automatically the next time the same hunk appears. That is what makes a weekly
merge cheap and a four-monthly one expensive.

## Commit titles

Examples:

- `feat: add platform contract example`
- `fix: harden fish alias bridging`
- `docs: simplify install guide`

## Regression tests

Files under `tests/regression/` must include a trace header within
the first 15 lines. One of three accepted forms:

```bash
# Regression for: GH-1234            # preferred — link to a GitHub issue
# Regression for: 1a2b3c4            # link to introducing commit (7+ hex chars)
# Regression for: pre-history        # explicit "origin not traceable"
```

The convention is enforced by the `regression-traceability` pre-commit
hook (`tools/ci/check-regression-traceability.sh`) and audited weekly
by `.github/workflows/regression-trace-audit.yml`, which fails the build
and opens a tracking issue if any `GH-*` reference no longer resolves
to a live issue. Use `pre-history` only when neither `git blame` nor
the related PR history yields an originating issue or commit.

## Day 1 verification

Run:

```bash
dot --version
dot doctor
make test
```

## Pull request hygiene

- Explain the change in one short paragraph
- List the verification commands
- Link the issue when one exists

GitHub uses [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)
for the web flow.
This file is the root entry point for local contributors.
