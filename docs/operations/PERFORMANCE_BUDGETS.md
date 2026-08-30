---
render_with_liquid: false
---

# Performance Budgets

Every operation this repo owns falls into one of four performance tiers. Each tier has a **hard budget** enforced by `tests/performance/test_perf_budgets.sh`. If a change pushes an operation past its budget's headroom, CI fails.

## The tiers

| Tier | Budget | What belongs here |
|---|---|---|
| **INSTANT** | ≤ **500ms** | Anything a human sees at a shell prompt |
| **FAST** | ≤ **2000ms** | Heavier gates + sandboxed CLI reads |
| **MEDIUM** | ≤ **5000ms** | Full diagnostic runs |
| **ACCEPTED-SLOW** | documented | Multi-second ops that are legitimately slow (see below) |
| **OUT-OF-SCOPE** | not gated | Multi-minute ops we don't gate per-run |

## Reference baselines (2026-08-30, `rousseau-cachyos-geekom-a9`, Ryzen AI 9 HX 370)

All medians in milliseconds. Budget = 2× median (or the tier ceiling, whichever is larger).

### INSTANT tier

| Operation | Baseline | Budget | Headroom |
|---|---:|---:|---:|
| `dot version` | 10 | 500 | 50× |
| `dot help` | 13 | 500 | 38× |
| `dot help <cmd>` | 15 | 500 | 33× |
| `dot search <keyword>` | 15 | 500 | 33× |
| iCloud script single-run | 15 | 500 | 33× |


### FAST tier

| Operation | Baseline | Budget | Headroom |
|---|---:|---:|---:|
| `dot status` (sandbox) | 1510 | 2000 | 1.3× |
| `dot diff` (sandbox) | 1420 | 2000 | 1.4× |

> The previous `dot status` / `dot diff` baselines of 28 ms and 32 ms were not
> real. The perf sandbox never created chezmoi's source directory, so both
> commands aborted immediately with *"no such file or directory"* — and
> `_measure` discarded exit codes, so the gate timed the failure path and
> called it excellent. The sandbox now links the repo into `XDG_DATA_HOME`,
> and the figures above are the commands actually running.

The QA gates and test suites that used to sit in this tier moved to GATES
below: they are not interactive operations, so a ceiling defined by
human-perceived latency never described them.

### MEDIUM tier

| Operation | Baseline | Budget | Headroom |
|---|---:|---:|---:|
| `dot doctor` | 3892 | 5000 | 1.3× |
| `bench.sh --quick` | 826 | 5000 | 6× |

Both MEDIUM entries are diagnostics that report findings through their exit
status — `dot doctor` exits 1 whenever it finds issues, and `bench.sh` exits 1
when a shell breaches its own startup threshold. They are gated with
`_gate_diag`, which permits exit 1 but still fails on 2+ (not-found,
permission, signal, syntax error). That is far narrower than the blanket
`|| true` it replaced.

### GATES tier (CI quality gates and test suites)

Budgets are 2× the median measured on the **slowest supported platform**,
not the fastest. Medians below: `rousseau-mbp-m1`, macOS 26 (Darwin 25.6),
2026-08-30.

| Operation | macOS median | Linux median | Budget | Headroom |
|---|---:|---:|---:|---:|
| `check-version-consistency.sh` | 68 | 14 | 500 | 7.4× |
| `docs-coverage.sh` | 969 | 148 | 2000 | 2.1× |
| iCloud regression test (12 assertions) | 494 | 94 | 1000 | 2.0× |
| iCloud unit test (29 assertions) | 1743 | 498 | 3500 | 2.0× |
| `traceability-coverage.sh` | 2389 | 623 | 5000 | 2.1× |
| `test_dot_subcommand_smoke.sh` | 3785 | 1308 | 7500 | 2.0× |
| `test_dot_help_registry_symmetry.sh` | 4449 | 1381 | 9000 | 2.0× |

These gates run **3–6× slower on macOS than on Linux** — fork/exec is markedly
more expensive there and every one of them is fork-heavy shell. CI covers both
platforms, so the original Linux-only calibration could not hold, and five of
these sat red as a result. Re-capture the Linux column when convenient; it is
carried over from the 2026-08-30 Ryzen baseline and is not the binding
constraint.

### ACCEPTED-SLOW (documented, not gated per-run)

| Operation | Baseline | Reason |
|---|---:|---|
| `test_dot_help_flag_universal.sh` | ~11s | Invokes `dot help --help` on ~100 commands via subshell each. The coverage it provides justifies the cost; regression is caught by `tests/performance/test_help_gates_wall_clock.sh` at the suite level. |

### OUT-OF-SCOPE (not gated per-run)

| Operation | Why we don't gate |
|---|---|
| `chezmoi apply` | Fresh macOS: minutes. Depends on iCloud sync + package installs. Gated at suite level only. |
| `install.sh` full | Downloads + installs packages. Network-bound. |
| `dot upgrade` | Runs `mise upgrade`, `chezmoi apply`, package manager upgrades. |
| Full test suite | 15+ minutes on CI. Gated by workflow timeout, not per-run assertion. |

## Ratchet vs aspiration

The budgets above are **regression gates**, not aspirations. If a real optimisation lowers a baseline, edit the doc + the perf test to lower the budget too. If a change pushes something over the budget, the test fails and CI blocks the merge.

The aspirational shell-startup target (`<30ms`) is tracked separately in `tests/performance/bench.sh` — that's a bench, not a budget.

## Adding a new operation

When you add a new script that runs at a shell prompt:

1. Time it 5 runs on a warm system: `for _ in {1..5}; do time bash your-script; done`
2. Take the median.
3. Place it in the tier where `budget ≥ 2 × median`. If a median is 400ms it goes in FAST (500ms is uncomfortably tight); if it's 300ms, INSTANT is fine.
4. Add it to `tests/performance/test_perf_budgets.sh` in the correct tier section.
5. Add its baseline to this doc.

## Where the enforcement lives

- **Per-op budget test**: `tests/performance/test_perf_budgets.sh`
- **Suite-level wall-clock ratchet**: `tests/performance/test_help_gates_wall_clock.sh`
- **CI wiring**: `.github/workflows/ci.yml`, job `quality-performance` — runs on
  ubuntu-latest and macos-latest for every PR, with no `|| true` and no budget
  scaling. Measured on the hosted macOS runner (2026-08-30), it is comparable to
  or faster than the reference machine on every gate — docs-coverage 679ms vs
  969, traceability 1775 vs 2389, help-registry 3318 vs 4449, `dot doctor` 1746
  vs 4423 — with a worst runner/local ratio of 1.25× (`dot search`). Budgets set
  at 2× the local median therefore keep ≥1.6× headroom in CI, so the gate runs
  strict.

## Environment knobs

| Variable | Default | Effect |
|---|---|---|
| `PERF_BUDGET_PERCENT` | `100` | Scales every budget. `0` makes them all impossible — that is how `test_gate_integrity.sh` proves the gate actually fires. |
| `PERF_GATE_FILTER` | *(unset)* | Runs only gates whose label contains this substring. Skipped gates never call `test_start`, so `TESTS_RUN == PASSED + FAILED` still holds. |
| `DOT_CLI` | `bin/dot` | Points the `dot` gates at another binary, so breakage detection can be exercised against a deliberately corrupted CLI. |

## When a budget fires

The error looks like:

```
✗ instant_dot_help: median=612ms EXCEEDS budget=500ms
```

Steps:

1. Bisect the change that pushed it over.
2. Fix the regression, or
3. If the increase is legitimate (real new work), move the operation to the next tier + update this doc + `test_perf_budgets.sh` in the same PR.

**Never silently bump the budget.** The tier a thing lives in is a promise to users.
