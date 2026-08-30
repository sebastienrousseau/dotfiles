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
| `check-version-consistency.sh` | 14 | 500 | 36× |
| `docs-coverage.sh` | 148 | 500 | 3.4× |
| iCloud regression test | 94 | 500 | 5.3× |

### FAST tier

| Operation | Baseline | Budget | Headroom |
|---|---:|---:|---:|
| `dot status` (sandbox) | 28 | 2000 | 71× |
| `dot diff` (sandbox) | 32 | 2000 | 62× |
| `traceability-coverage.sh` | 623 | 2000 | 3.2× |
| iCloud unit test (29 assertions) | 498 | 2000 | 4× |
| `test_dot_subcommand_smoke.sh` | 1308 | 2000 | 1.5× |
| `test_dot_help_registry_symmetry.sh` | 1381 | 2000 | 1.4× |

### MEDIUM tier

| Operation | Baseline | Budget | Headroom |
|---|---:|---:|---:|
| `dot doctor` | 3892 | 5000 | 1.3× |
| `bench.sh --quick` | 826 | 5000 | 6× |

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
- **CI wiring**: `.github/workflows/dot-cli-coverage.yml` (add here to run on every PR)

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
