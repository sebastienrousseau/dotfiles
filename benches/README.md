# `benches/` — benchmarks

Canonical home for performance measurement. Nothing here asserts a
pass/fail threshold on its own; the gates that *do* fail CI live in
`tools/ci/dot-cli-startup-bench.sh` (cold-start budget, run by
`.github/workflows/dot-cli-bench.yml`) and `scripts/diagnostics/perf.sh`
(baseline comparison, run by `.github/workflows/perf-baseline.yml`).

| Script | Measures | Run by |
|--------|----------|--------|
| `bench.sh` | Shell startup latency per shell (hyperfine), quick pass/fail against target thresholds. Invoked by `dot doctor` when hyperfine is installed. | `scripts/diagnostics/doctor.sh` |
| `benchmark_runner.sh` | Full performance regression benchmark; writes `benchmark_*.json` results. | `.github/workflows/ci.yml` (smoke-run, non-gating), `.github/workflows/nightly.yml` |
| `regression_check.sh` | Compares the latest `benchmark_*.json` against the previous run. | manual |
| `stress_test.sh` | Load test: repeated shell spawns under contention. | manual |
| `test_help_gates_wall_clock.sh` | Wall-clock budget for the `dot help` regression gates. | manual |

## Run locally

```sh
make bench                       # smoke-run every benchmark (kept runnable, not asserted)
bash benches/benchmark_runner.sh # full run with JSON output
bash benches/regression_check.sh # compare against previous JSON
```

Benchmarks are smoke-run on every push (the `make bench` target is what
CI calls) so they cannot silently rot; numbers are tracked, not
asserted, because runner variance makes absolute thresholds flaky.
The one exception is the `dot` cold-start budget, which is a hard gate.
