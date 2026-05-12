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
