# `benches/` — benchmarks

Canonical home for performance measurement. Most scripts here record
numbers without failing CI. Two gates do fail it:
`benches/test_perf_budgets.sh` (tiered command and startup budgets, run
by the `Quality / Performance budgets` jobs in `.github/workflows/ci.yml`) and
`tools/ci/dot-cli-startup-bench.sh` (the `dot` cold-start budget, run by
`.github/workflows/dot-cli-bench.yml`). `scripts/diagnostics/perf.sh`
(baseline comparison, run by `.github/workflows/perf-baseline.yml`)
opens an issue on a regression.

| Script | Measures | Run by |
|--------|----------|--------|
| `bench.sh` | Shell startup latency per shell (hyperfine), quick pass/fail against target thresholds. Invoked by `dot doctor` when hyperfine is installed. | `scripts/diagnostics/doctor.sh` |
| `test_perf_budgets.sh` | Every performance budget in one place, tiered, with a runner-calibration factor. **Gating.** | `.github/workflows/ci.yml` (`quality-performance`) |
| `dot_command_bench.sh` | Cold-start time of every routed `dot` command; the command list is `run-cases.txt`. | `.github/workflows/dot-cli-bench.yml` (`sweep`; records JSON, then `scripts/qa/check-feature-matrix.sh` asserts every command was reached) |
| `benchmark_runner.sh` | Full performance regression benchmark; writes `benchmark_*.json` results. | `.github/workflows/ci.yml` (`benchmark`, on the weekly schedule and dispatch only; run directly, non-gating) |
| `regression_check.sh` | Compares the latest `benchmark_*.json` against the previous run. | manual |
| `stress_test.sh` | Load test: repeated shell spawns under contention. | manual |
| `test_help_gates_wall_clock.sh` | Wall-clock budget for the `dot help` regression gates. | `.github/workflows/ci.yml` (`benchmark`, same schedule; advisory: `continue-on-error`) |

## Run locally

```sh
make bench                         # runs benchmark_runner.sh (kept runnable, not asserted)
bash benches/benchmark_runner.sh   # the same, directly
bash benches/regression_check.sh   # compare against previous JSON
bash benches/test_perf_budgets.sh  # the CI budget gate
```

`benchmark_runner.sh` runs in CI every week so it cannot silently rot;
its numbers are tracked, not asserted, because runner variance makes
absolute thresholds flaky. The budget gate and the `dot` cold-start
budget are the exceptions, and both are hard gates.
