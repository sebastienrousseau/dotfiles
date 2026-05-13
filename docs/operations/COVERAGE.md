# Code Coverage

This page documents how coverage is measured, what the threshold is,
how to run it locally, and how to triage a regression. Closes the
docs slice of [#856](https://github.com/sebastienrousseau/dotfiles/issues/856).

## Why kcov

The repo's primary code surface is bash (~140 shell files under
`scripts/`, hundreds more in `.chezmoitemplates/`). Standard
language-specific coverage tools (`coverage.py`, `cargo tarpaulin`,
`go cover`) don't apply.

[kcov](https://github.com/SimonKagstrom/kcov) instruments bash via
DWARF debugger interfaces: it observes each `bash -x` line execution
without modifying the source files, and emits standard `lcov.info`
(plus Cobertura XML) that Codecov / Codacy / GitHub Code Scanning
all ingest natively.

## Where it runs

| Surface | What runs |
|---|---|
| **PR + push to master** | `.github/workflows/coverage.yml` → `Coverage / kcov` job → uploads lcov.info to Codecov and fails the build below `MIN_COVERAGE_PCT` (currently `50`, tightened over time). |
| **Local dev** | `bash scripts/ci/run-coverage.sh` — Linux-only (kcov on macOS requires private-API patches); skips silently on Darwin so the same command works in pre-commit on any platform. |
| **macOS dev** | Not supported by kcov. The `Coverage / kcov` CI job covers PRs from macOS contributors via the Linux runner. |

## The current floor

`MIN_COVERAGE_PCT=50` in `.github/workflows/coverage.yml`. The
workflow fails the build if measured coverage drops below this. The
floor is intentionally low to start — see "Why not 100% yet" below.

To tighten:

1. Land a few PRs that bump coverage.
2. Wait until two-three Codecov runs report a stable value (no
   per-PR jitter).
3. Edit `MIN_COVERAGE_PCT` upward by ≤5 percentage points per bump.
4. Note the floor change in the commit message + this page.

## Running locally

```bash
# Linux only:
sudo apt-get install -y kcov
bash scripts/ci/run-coverage.sh

# Output:
#   coverage/<file>.kcov/      — per-test kcov runs
#   coverage/merged/           — kcov --merge artifacts
#   coverage/lcov.info         — lcov-format report Codecov ingests
```

Open `coverage/merged/index.html` in a browser for the per-file
heatmap.

## Triaging a regression

When the `Coverage / kcov` PR check fails:

1. Pull the workflow's `coverage-lcov` artifact (30-day retention).
2. Compare against the previous master run by downloading its
   `coverage-lcov` artifact too.
3. Identify the file(s) where the line-coverage dropped.
4. Either:
   - Add tests covering the new code, or
   - If the new code is provably unreachable in the test corpus
     (e.g., a platform-specific branch only macOS tests exercise),
     update the test suite to invoke it. Don't carve out global
     exemptions — they accumulate.

## Why not 100% yet

The previous workflow advertised "100% Coverage" without measuring
anything. Going from `0% measured` to `100% enforced` overnight is a
recipe for either:

- Suppressing the gate to ship anything ("just lower the threshold,
  we'll fix it later"), or
- Padding the test suite with assertions that don't actually
  exercise the code under test.

So this page documents a graduated approach: start with a measured
floor at 50%, ratchet upward as the test surface catches up to the
code surface. The previous aspirational "100%" labels in CI/job
names + branch-protection contexts have been renamed to match
reality (`Test / Unit Tests` instead of `Test / Unit Tests (100%
Coverage)`).

## Codecov integration

Codecov (free OSS tier) is the canonical badge + PR-comment source.
The upload uses the
[`codecov/codecov-action`](https://github.com/codecov/codecov-action)
in tokenless mode (works for public repos out of the box; private
repos need `CODECOV_TOKEN`).

The Codecov GitHub App posts a status check on each PR with the
line-by-line diff coverage. Combine with this workflow's job-level
threshold to get two independent signals.

## Excluded paths

`scripts/ci/run-coverage.sh` excludes:

- `tests/**` itself (don't measure coverage of the tests).
- `.git/`, `node_modules/`.
- Paths matched by `KCOV_EXCLUDE_PATTERN` (defaults reasonable).

Included paths (`KCOV_INCLUDE_PATH`):

- `scripts/`
- `.chezmoitemplates/functions/`
- `dot_local/bin/`

Adjust via the env vars at the top of `run-coverage.sh`.

## References

- [kcov project](https://github.com/SimonKagstrom/kcov).
- [`scripts/ci/run-coverage.sh`](../../scripts/ci/run-coverage.sh).
- [`.github/workflows/coverage.yml`](../../.github/workflows/coverage.yml).
- Issue [#856](https://github.com/sebastienrousseau/dotfiles/issues/856).
