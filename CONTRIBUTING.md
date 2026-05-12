# Contributing

Keep changes small. Keep them signed. Keep them tested.

## Before opening a pull request

Run:

```bash
make test
bash scripts/git-hooks/pre-push
```

Use a signed commit:

```bash
git commit -S -m "fix: concise summary"
```

The pre-push audit is **mandatory by default**. If you need to bypass
it for a single push (rare, almost never on `master`), see
[`docs/security/AUDIT_BYPASS.md`](docs/security/AUDIT_BYPASS.md). The
legacy `DOTFILES_SKIP_PRE_PUSH_AUDIT=1` variable is no longer honored.

## Pre-commit hooks

The repo ships a `pre-commit` configuration that mirrors CI. Install
once:

```bash
pip install --user pre-commit          # or: brew install pre-commit
pre-commit install --config config/pre-commit-config.yaml
```

Run every hook against every file (do this after fresh-cloning, after
big merges, or when CI surfaces a hook you don't have locally):

```bash
pre-commit run --all-files --config config/pre-commit-config.yaml
```

Hooks in this config (shellcheck, shfmt, hadolint, gitleaks,
detect-secrets, checkov, conventional-commit linter, typos-cli,
actionlint, **luacheck**, **stylua**, plus repo-local custom hooks)
run on commit by default. The `luacheck` and `stylua` hooks are pinned
to the same versions CI uses; if you bump one, bump the other in the
same PR (see [`config/pre-commit-config.yaml`](config/pre-commit-config.yaml)
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

## Commit titles

Examples:
- `feat: add platform contract example`
- `fix: harden fish alias bridging`
- `docs: simplify install guide`

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
