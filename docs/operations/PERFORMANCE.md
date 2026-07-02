---
render_with_liquid: false
---

# Performance — Budgets, Baselines, Regression Detection

This page documents the per-shell startup budget, the baseline
lifecycle, and the regression-alert pipeline. Managed under
[#863](https://github.com/sebastienrousseau/dotfiles/issues/863).

## Targets

| Shell | Target (mean ms) | Override env var |
|---|---|---|
| **zsh** | 250 | `DOTFILES_PERF_TARGET_ZSH_MS` |
| **bash** | 60 | `DOTFILES_PERF_TARGET_BASH_MS` |
| **fish** | 200 | `DOTFILES_PERF_TARGET_FISH_MS` |
| **nu** | 500 | `DOTFILES_PERF_TARGET_NU_MS` |
| **pwsh** | 600 | `DOTFILES_PERF_TARGET_PWSH_MS` |

`dot perf` measures every installed shell and flags any whose mean
exceeds its target. The numbers come from
[`scripts/diagnostics/perf.sh`](https://github.com/sebastienrousseau/dotfiles/blob/master/scripts/diagnostics/perf.sh) —
warm-up + 3 runs by default.

## The baseline

`$XDG_CACHE_HOME/dotfiles/perf-baseline.json` records the per-shell
means at a known-good point in time. The file is a JSON object:

```json
{
  "recorded_at": "2026-05-13T00:00:00Z",
  "regression_pct": 10,
  "shells": {
    "zsh": 41,
    "bash": 28,
    "fish": 190
  }
}
```

### Recording a baseline

```bash
dot perf --baseline                 # all installed shells
dot perf --baseline --shell zsh     # just one shell
```

Do this after:

- A fresh chezmoi apply on a new machine.
- Any deliberate startup-cost change (deferred-load PRs, new plugin).
- A `mise install` that bumps a hot-path tool's version.

### Regression detection

Every subsequent `dot perf` invocation compares the current
measurement against the baseline. When any shell exceeds the
baseline by more than `DOTFILES_PERF_REGRESSION_PCT` (default 10%),
the run reports under a "Baseline regressions" section. JSON output
includes a `regressions: [...]` array and a `regression_count`
counter so dashboards can alert.

```bash
dot perf                            # warns on regression
dot perf --no-baseline-check        # skip the comparison entirely
DOTFILES_PERF_REGRESSION_PCT=5 dot perf   # tighter threshold
```

## Per-tool timings

`_cached_eval` (the zsh/fish primitive that caches expensive tool
init like `starship init zsh`) writes one JSONL row per call to
`$XDG_STATE_HOME/dotfiles/eval-timings.jsonl` when
`EVALCACHE_TIMING=1` is set in the environment. Aggregating that log
gives a per-tool breakdown of where startup time goes.

```bash
EVALCACHE_TIMING=1 zsh -i -c exit    # generate data
dot perf --by-tool                   # see the aggregation
dot perf --reset                     # clear the log
```

The aggregator reports `count / total / mean / p50 / p95 / p99`
per `_cached_eval` label. P95 + P99 surface the tail-latency cases
that mean alone misses (e.g. a cache miss after a tool upgrade
spiking from 5ms steady-state to 200ms once).

## `dot doctor` Performance section

`dot doctor` surfaces (when each data source is available):

- Whether `_cached_eval`'s on-disk tool caches are fresh vs stale
  for mise, starship, zoxide, atuin, fzf, direnv.
- Any installed slow-init tools NOT yet wrapped in `_cached_eval`
  (nvm, fnm, pyenv, pnpm, …).
- Hyperfine-measured startup latency vs target.
- Baseline age + top-3 slowest tools from the EVALCACHE_TIMING log.

## CI workflow

[`.github/workflows/perf-baseline.yml`](https://github.com/sebastienrousseau/dotfiles/blob/master/.github/workflows/perf-baseline.yml)
runs weekly on Sunday at 03:00 UTC on `ubuntu-latest`. It:

1. Restores the previous week's baseline from a workflow artifact.
2. Runs `dot perf --json` against the freshly-applied dotfiles.
3. Compares current vs restored baseline; opens (or comments on) a
   tracking issue if any shell regressed by >10%.
4. Uploads the new measurement as the next week's restore source.

The CI workflow always runs against the same `ubuntu-latest` image
so the comparison is machine-stable; per-developer baselines live on
each developer's box and aren't synced.

## Adjusting the budget

Per-shell targets live in
[`scripts/diagnostics/perf.sh`](https://github.com/sebastienrousseau/dotfiles/blob/master/scripts/diagnostics/perf.sh)
under `shell_target_for()`. Bumping a target should always come with:

- A commit-message rationale explaining why slower is acceptable
  (e.g. "added a required Carapace completion at startup").
- A new baseline recording (`dot perf --baseline`).
- A note here under "Targets" with the new value.

## References

- [`scripts/diagnostics/perf.sh`](https://github.com/sebastienrousseau/dotfiles/blob/master/scripts/diagnostics/perf.sh)
- [`tests/unit/diagnostics/test_perf_percentiles.sh`](https://github.com/sebastienrousseau/dotfiles/blob/master/tests/unit/diagnostics/test_perf_percentiles.sh) — percentile math contract
- [`.github/workflows/perf-baseline.yml`](https://github.com/sebastienrousseau/dotfiles/blob/master/.github/workflows/perf-baseline.yml)
- ADR-002 (Shell Performance Optimization)
- Issue [#863](https://github.com/sebastienrousseau/dotfiles/issues/863)
