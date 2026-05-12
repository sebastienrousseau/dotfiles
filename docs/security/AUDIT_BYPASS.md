# Pre-Push Audit Bypass

This page documents when the pre-push reliability audit can be bypassed,
how to do it, and why the answer is "almost never on `master`."

## Background

`scripts/git-hooks/pre-push` runs two checks on every push:

1. **Signed-commit verification** — every commit being pushed must have
   a valid GPG/SSH signature. No bypass is available; an unsigned
   commit is refused unconditionally.

2. **Reliability audit** — `scripts/qa/reliability-audit.sh --quick`
   runs a fast subset of the test suite + lint checks. This is the
   step that can be bypassed.

Before issue #871 the audit was opt-out: `DOTFILES_SKIP_PRE_PUSH_AUDIT=1`
in your shell rc would silently skip every push's audit. Bypass was
invisible, persistent, and one keystroke away. That's the wrong default.

## The new policy

Effective with #871 and the corresponding commit on this branch:

- The audit **always runs by default**. Missing env var → audit runs.
- Bypass requires `DOTFILES_ALLOW_UNSKIPPED_PUSH=1` set inline for the
  one push you want to bypass (not exported in your shell rc).
- The legacy `DOTFILES_SKIP_PRE_PUSH_AUDIT=1` is **rejected** with a
  migration message; the hook exits non-zero if it sees the old var.
- Every bypass is appended to
  `${XDG_STATE_HOME:-~/.local/state}/dotfiles/audit-bypass.log` with
  timestamp, branch, remote, and reason.
- `dot doctor` reports the count of bypasses in the last 7 days.

The new variable name is deliberately awkward
(`DOTFILES_ALLOW_UNSKIPPED_PUSH`) — it should not feel like a routine
flag. Setting it should require a moment's thought.

## How to bypass for a single push

```bash
DOTFILES_ALLOW_UNSKIPPED_PUSH=1 \
DOTFILES_BYPASS_REASON='hotfix: CI is wedged on flake' \
  git push origin hotfix/my-branch
```

The reason string is optional but encouraged. It lands in the audit log
so `dot doctor` and any future review can answer "why was this
bypassed?" without git archaeology.

## When bypass is legitimate

Short list — anything outside this is suspicious:

- **Hotfix push to a non-master branch** when CI infrastructure itself
  is the audit blocker (e.g., the audit pre-flight depends on a remote
  service that's down). The fix should land *before* the
  infrastructure recovers; bypass is the bridge.
- **Force-push of a tag rewind** that doesn't introduce new commits
  (rare).

When bypass is **not** legitimate:

- Routine `master` pushes. The whole point of the audit is to guard
  the protected branch.
- Pushes whose audit failure is "annoying" — the right move is to fix
  the failure, not skip the check.
- CI environments. CI should run the audit explicitly, never bypass
  it; if a CI job pushes, the env var must remain unset there.

## Verifying current state

```bash
dot doctor   # surfaces recent bypasses
cat ${XDG_STATE_HOME:-~/.local/state}/dotfiles/audit-bypass.log
```

Each line of the log is tab-separated:
`ISO8601-timestamp \t branch=... \t remote=... \t reason=...`.

## Disabling bypass entirely

If your machine should *never* bypass (e.g., a release runner), unset
the env var in your shell rc and add a guard to your `.zshenv` or
equivalent:

```bash
unset DOTFILES_ALLOW_UNSKIPPED_PUSH
```

There's no way to permanently grant bypass — that's intentional.

## References

- `scripts/git-hooks/pre-push` — the hook itself
- `scripts/diagnostics/doctor.sh` — the "Pre-Push Audit Bypass" section
- `tests/unit/security/test_pre_push_bypass.sh` — regression test
- Issue #871
