---
render_with_liquid: false
---

# Code Coverage

This page documents how coverage is measured, what the threshold is,
how to run it locally, and how to triage a regression. Closes the
docs slice of [#856](https://github.com/sebastienrousseau/dotfiles/issues/856).

## Why pure bash xtrace (and not kcov)

The repo's primary code surface is bash (~140 shell files under
`scripts/`, hundreds more in `.chezmoitemplates/`). Standard
language-specific coverage tools (`coverage.py`, `cargo tarpaulin`,
`go cover`) don't apply.

We originally targeted [kcov](https://github.com/SimonKagstrom/kcov),
but kcov v43 on Ubuntu 24.04 + bash 5.2 cannot produce bash-script
coverage in any configuration we tried:

- Without bash debug symbols, kcov's ptrace backend fails to resolve
  breakpoints and emits zero lines.
- With `bash-dbgsym` installed, kcov switches into C-binary tracking
  mode and emits coverage entries for bash's internal C headers
  (`ctype.h`, `stdio.h`, `wchar.h`) instead of the `.sh` files we
  want measured.

Instead we use bash's own xtrace mechanism:

```bash
PS4='+@COV@:${LINENO}:${BASH_SOURCE}:@ '   # encode line + source
BASH_ENV=/tmp/cov-setup.sh                  # `set -x` in every bash
bash test.sh 2>traces/test.trace            # capture stderr per test
```

`BASH_ENV` is inherited by every non-interactive bash invocation, so
subprocess `bash $SCRIPT_FILE` calls inside tests are also traced
automatically. The runner parses every trace for `:LINENO:FILE:`
matches and emits standard `lcov.info` that Codecov ingests natively.

## Where it runs

| Surface | What runs |
|---|---|
| **PR + push to main** | `.github/workflows/coverage.yml` → `Coverage / kcov` job → uploads lcov.info to Codecov and fails the build below `MIN_COVERAGE_PCT` (currently `41`, ratcheted up each slice). |
| **Local dev** | `bash tools/ci/run-coverage.sh` — works on Linux + macOS (xtrace is a bash primitive, no platform tools needed). |
| **macOS dev** | Supported. xtrace-based instrumentation runs on macOS bash 3.2+ and Homebrew bash 5.x. |

## The current floor

`MIN_COVERAGE_PCT=41` in `.github/workflows/coverage.yml`. Slice 1
of [#883](https://github.com/sebastienrousseau/dotfiles/issues/883)
established the baseline at **~2.7% measured** (~613 of ~22 500 lines
across 231 files). Successive slices raised it; the current measured
value sits at **41.35%** (`5115/12371` lines) after the second core
coverage-ratchet slice drove `scripts/dot/commands/tools.sh` to 72.85%,
`lib/dot/utils.sh` to 73.24%, and `scripts/version-sync.sh` to 36.53%.
This builds on the first core slice for `lib/dot/ui.sh` and the #954
deep-branch pass for `scripts/theme/switch.sh`,
`scripts/diagnostics/mcp-doctor.sh`, and Linux/WSL branches in
`scripts/diagnostics/doctor.sh`.

To tighten:

1. Land a slice that bumps measured coverage.
2. Wait until two-three Codecov runs report a stable value (no
   per-PR jitter).
3. Edit `MIN_COVERAGE_PCT` upward, ideally by ≤15 percentage points
   per bump.
4. Note the floor change in the commit message + this page.

### Why not the 95% target from #883

The roadmap originally targeted ≥95% measured. After working through
all six slices, the achievable ceiling with xtrace-only instrumentation
is closer to **~50%** on this codebase. The remaining gap is structural,
not aspirational:

- **System-mutation surface** — large parts of the repo orchestrate
  real OS state (`chezmoi apply`, `gpg`, `pass`/`age` keystores,
  `gsettings`, signal-driven app reload, `git reset --hard`,
  filesystem backups). Exercising these requires either a destroyable
  sandbox (Docker / VM) or per-call mocks for every system tool.
- **Platform-gated branches** — every diagnostic and theme script
  has Darwin / Linux / WSL forks. The xtrace runner only sees the
  fork for the host it ran on; the others remain "uncovered"
  forever from that one run's perspective. CI runs both macOS and
  Linux but reports them separately.
- **Interactive UIs** — `fzf`, `gum`, `cmatrix`, `niri`, and the
  Ghostty/Tmux reload helpers can't return to the test under
  `bash -x` within a timeout budget. These are excluded at the
  aggregator level.
- **Animated demo helpers** — same as interactive UIs.

`tools/ci/run-coverage.sh` has a `SKIP_PATHS` set that removes
genuinely-untestable scripts from the lcov denominator. Within the
files that remain, individual mutation-only function bodies are
fenced with `# LCOV_EXCL_START` / `# LCOV_EXCL_STOP` and a one-line
rationale comment. Every exclusion line names the reason (`rm -rf
real $HOME`, `signals live apps`, `gpg keystore`, etc.) so future
maintainers can re-evaluate if the test infrastructure changes.

The graduated approach in this doc replaces the original 95% target.
The honest floor is the achievable one.

## Running locally

```bash
bash tools/ci/run-coverage.sh   # Linux or macOS

# Output:
#   coverage/traces/<file>.trace  — per-test xtrace logs
#   coverage/lcov.info            — lcov-format report Codecov ingests
```

Open `coverage/lcov.info` in any lcov visualizer
(`genhtml coverage/lcov.info -o coverage/html`) for the per-file
heatmap.

## Triaging a regression

When the `Coverage / kcov` PR check fails:

1. Pull the workflow's `coverage-lcov` artifact (30-day retention).
2. Compare against the previous main run by downloading its
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

`tools/ci/run-coverage.sh` excludes:

- `tests/**` itself (don't measure coverage of the tests).
- `.git/`, `node_modules/`.
- Paths matched by `KCOV_EXCLUDE_PATTERN` (defaults reasonable).

Included paths (`KCOV_INCLUDE_PATH`):

- `scripts/`
- `.chezmoitemplates/functions/`
- `dot_local/bin/`

Adjust via the env vars at the top of `run-coverage.sh`.

## References

- [Bash xtrace + PS4 + BASH_ENV docs](https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html).
- [`tools/ci/run-coverage.sh`](https://github.com/sebastienrousseau/dotfiles/blob/main/tools/ci/run-coverage.sh).
- [`.github/workflows/coverage.yml`](https://github.com/sebastienrousseau/dotfiles/blob/main/.github/workflows/coverage.yml).
- Issue [#856](https://github.com/sebastienrousseau/dotfiles/issues/856) (closed) /
  [#883](https://github.com/sebastienrousseau/dotfiles/issues/883) (coverage roadmap).
