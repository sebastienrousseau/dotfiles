---
render_with_liquid: false
---

# deps.dev Advisory Exceptions

The CI workflow `.github/workflows/deps-dev-validation.yml` scans
direct dependencies (npm + PyPI + GitHub Actions) against the
[deps.dev Insights API](https://docs.deps.dev/) on every PR, every
push to `main`, and every Tuesday at 04:00 UTC. When an advisory
is reported at or above the threshold (default `HIGH`), the workflow
fails.

This page is where time-bound exceptions live. An entry here suppresses
the check for one specific `(ecosystem, package)` pair, with an expiry
date so the exception cannot accumulate quietly.

Managed under [#877](https://github.com/sebastienrousseau/dotfiles/issues/877).

## Active exceptions

*(none currently)*

## Adding an exception

Add an entry below in this exact format — the scanner greps for
`` `<ecosystem>:<package>` `` at the start of a line (case-sensitive,
backtick-delimited):

```
`NPM:lodash` (expires 2026-12-31): Maintained fork; advisory affects
only the unused stream-API code path. Confirmed via static analysis.
Tracked under #NNNN.
```

`<ecosystem>` is one of:

| Ecosystem | Source |
|---|---|
| `NPM` | `package.json` direct deps |
| `PYPI` | `pyproject.toml` direct deps |
| `GITHUB_ACTIONS` | `uses:` references in `.github/workflows/*.yml` |

`(expires YYYY-MM-DD)` is required. Use a 90-day window for routine
work; longer windows need a sentence explaining why and a follow-up
issue link.

## When to add vs not add

**Legitimate exception**:

- The advisory is in a code path your usage doesn't reach (e.g.
  vulnerable function isn't called by anything in this repo).
- The upstream fix is in flight and you've already opened a PR or
  bumped to a beta.
- The package is end-of-life and you're tracking the migration to a
  successor under a dedicated issue.

**Not an exception** — fix the dep instead:

- "Bumping the version is annoying" — that's the whole point of the
  gate.
- "The advisory might be a false positive" — verify via deps.dev's
  underlying source; if confirmed FP, file with deps.dev rather than
  exception here.
- "We don't have time this sprint" — that's a deferral, not an
  exception. Bump the issue to next sprint, don't suppress.

## Expiry policy

The scanner does not currently parse expiry dates (deferred — needs
a date-comparison helper). A monthly maintainer review of this page
is the human gate. Any entry past its expiry should either be
resolved (dep bumped, exception removed) or re-justified with a new
expiry.

When the date-parsing automation lands, expired exceptions will
auto-fail the gate even when they're still listed here.

## References

- [`tools/ci/check-deps-dev.sh`](https://github.com/sebastienrousseau/dotfiles/blob/main/tools/ci/check-deps-dev.sh) — the scanner.
- [`.github/workflows/deps-dev-validation.yml`](https://github.com/sebastienrousseau/dotfiles/blob/main/.github/workflows/deps-dev-validation.yml) — CI wiring.
- [`tests/unit/security/test_check_deps_dev.sh`](https://github.com/sebastienrousseau/dotfiles/blob/main/tests/unit/security/test_check_deps_dev.sh) — contract test against canned fixtures.
- [deps.dev API reference](https://docs.deps.dev/api/v3/).
- Issue [#877](https://github.com/sebastienrousseau/dotfiles/issues/877).
