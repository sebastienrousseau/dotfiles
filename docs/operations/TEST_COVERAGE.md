---
render_with_liquid: false
---

# Test Coverage — Structure & Targets

Companion to [`COVERAGE.md`](COVERAGE.md) (which covers the
mechanics of coverage generation). This document is the map: what
each test category covers, what the targets are, and where to add
a new test.

## Categories

The test tree under `tests/` splits into seven categories, each
with a distinct purpose and reporting stream:

| Category | Files | Runs when | Blocks merge? | Reports to |
|---|---:|---|---|---|
| `framework/` | 3 | Bootstrap of all test runs | N/A — infrastructure | — |
| `unit/` | ~600 | On every push + PR (matrix) | **Yes** | codecov, reliability-gate |
| `integration/` | ~30 | On every push + PR | **Yes** | reliability-gate |
| `regression/` | ~15 | On every push + PR | **Yes** | reliability-gate |
| `snapshots/` | ~10 | On every push (snapshot drift) | **Yes** on drift | GitHub issue |
| `performance/` | ~5 | Nightly + `[perf]` label on PR | **Advisory** — regression comments on PR | perf-baseline artefact |
| `fuzz/` | ~15 | Nightly (`fuzz.yml`) | **Advisory** — new crashes filed as issues | OSS-Fuzz + `nightly-reports/` |

Total: 681 test files today (see `bash scripts/qa/shell-surface-audit.sh | grep test`).

## What each category covers

### `unit/`
One-to-one shadow of the source tree. Every file under `lib/dot/`,
`scripts/dot/commands/`, `scripts/ops/`, `scripts/security/`,
`scripts/diagnostics/`, `scripts/theme/` has a corresponding
`tests/unit/<domain>/test_<name>.sh`. Domain subdirectories:

```
tests/unit/aliases/       tests/unit/auto/         tests/unit/ci/
tests/unit/diagnostics/   tests/unit/docs/         tests/unit/dot-cli/
tests/unit/fish/          tests/unit/fleet/        tests/unit/functions/
tests/unit/init/          tests/unit/install/      tests/unit/misc/
tests/unit/nushell/       tests/unit/nvim/         tests/unit/ops/
tests/unit/qa/            tests/unit/secrets/      tests/unit/security/
tests/unit/shell/         tests/unit/theme/
```

Assertions in each file use `tests/framework/assertions.sh`; live
coverage is driven by `tests/framework/coverage_helpers.sh::cov_exercise_script`
which sources the target and reports the executed line set.

### `integration/`
Whole-flow tests that exercise `bin/dot` + subcommand + backing
scripts + chezmoi in concert. Runs in a sandbox `$HOME` so the
host machine is never touched. Each test brings up the sandbox,
runs a scenario end-to-end, and asserts the resulting file/state
shape.

### `regression/`
One file per historically-broken behaviour. New regression tests
land alongside the bug fix in the same PR. Reading the directory
listing is the fastest way to see what has failed in production
before.

Examples:
- `test_static_analysis.sh` — shellcheck/shfmt drift on changed files
- `test_phase4b_chezmoiroot_paths.sh` — chezmoi source-tree layout
- `test_signed_history_recovery.sh` — signature-enforcement recovery

### `snapshots/`
Golden-file comparisons for outputs whose shape matters more than
their content (help text, `--json` schemas, generated manpages).
Fails when the output shape drifts from the committed snapshot;
`dot snapshot update` regenerates.

### `performance/`
Micro-benchmarks against `nightly-reports/perf-baseline.json`. The
headline invariant is sub-100ms CLI cold-start; individual
subcommands have their own budgets in `docs/operations/PERFORMANCE.md`.

### `fuzz/`
Uses the OSS-Fuzz integration under `oss-fuzz-integration/`. Corpus
under `tests/fuzz/`. Currently focused on argv parsing and template
rendering.

## Coverage targets

Line coverage (as reported by codecov):

| Path | Current | 1.0 target |
|---|---:|---:|
| `lib/dot/` | ~72 % | **≥ 80 %** |
| `scripts/dot/commands/` | ~68 % | **≥ 80 %** |
| `scripts/ops/` | ~55 % | **≥ 80 %** |
| `scripts/security/` | ~60 % | **≥ 80 %** |
| `scripts/diagnostics/` | ~65 % | **≥ 75 %** |
| `install/lib/` | ~40 % | **≥ 60 %** (installer paths are hard) |
| `bin/` | ~85 % | **≥ 90 %** |

Coverage is a **trend metric**, not a hard gate — a PR that drops
coverage gets a comment but not a failure. The reliability-gate is
what blocks merges. The 1.0 targets above will become hard gates
per [`RELEASE_1_0.md`](RELEASE_1_0.md).

## Where to add a new test

| Change type | Test to add / update |
|---|---|
| New `lib/dot/` function | `tests/unit/dot-cli/test_dot_lib_<file>.sh` — cover happy path, edge cases, invariants (silence, idempotence) |
| New `dot` subcommand | `tests/unit/<domain>/test_dot_<command>.sh` + `tests/integration/test_dot_<command>_flow.sh` + snapshot for `--help` |
| Bug fix | `tests/regression/test_<issue-slug>.sh` — reproduce the bug before the fix, verify it goes green after |
| New chezmoi template | `tests/unit/auto/test_auto__<path>.sh` (auto-tests are scaffolded by `scripts/qa/scaffold-test.sh`) |
| Performance-critical change | `tests/performance/bench_<subject>.sh` + update `nightly-reports/perf-baseline.json` in the same PR |

## Running the suite

```bash
# Full suite (matches CI)
./tests/framework/test_runner.sh

# Single category
./tests/framework/test_runner.sh --category unit

# Single file
bash tests/unit/dot-cli/test_dot_lib_utils.sh

# With coverage
./tests/framework/test_runner.sh --coverage
```

Set `TEST_VERBOSE=1` to see each assertion; set `TEST_FAIL_FAST=1`
to stop on first failure.

## Fitness function

A change to the codebase is considered "test-covered" when:

1. Every new public function has ≥1 unit test asserting its happy
   path.
2. Every new invariant (silence, idempotence, exit-code contract)
   has ≥1 test asserting the invariant.
3. Bug fixes always land with a regression test.
4. Coverage did not decrease in the change (measured by codecov
   delta).

CI does not enforce (1)–(3) — they're review-time expectations
called out in `.github/PULL_REQUEST_TEMPLATE.md`.

## Related

- [`COVERAGE.md`](COVERAGE.md) — coverage generation mechanics
- [`METRICS.md`](METRICS.md) — where coverage fits in the broader observability picture
- [`RELIABILITY.md`](RELIABILITY.md) — how tests compose into the reliability-gate
- [`RELEASE_1_0.md`](RELEASE_1_0.md) — coverage gates for v1.0
