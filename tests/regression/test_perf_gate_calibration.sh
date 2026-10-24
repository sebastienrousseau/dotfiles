#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Regression for: 26c1d5af
# shellcheck disable=SC1090,SC1091,SC2034
#
# The performance gate (benches/test_perf_budgets.sh) compares wall-clock
# medians with fixed budgets. On shared macOS runners the spawn-heavy gates
# swung 3x between runs of the same code, and five samples instead of three
# (26c1d5af) did not stop them failing main. The gate now times a reference
# workload first and scales every budget by how much slower than the
# reference machine this runner is, capped so a hopeless runner fails.
#
# Every scenario runs the real gate against a synthetic, spawn-bound CLI
# (DOT_CLI) through its `instant_dot_version` entry, and simulates a slow
# runner with a `bash` on PATH that pays for an extra bash spawn every time
# it starts. That slows the calibration workload and the gated command alike,
# as a slow runner does. The reference is set to this machine's own
# unslowed calibration, so the test is relative to wherever it runs.
#
#   1. slow runner, same code         -> the gate passes (it failed before)
#   2. slow runner, gated command 3x  -> the gate still fails
#   3. runner beyond the factor cap   -> the run fails and says why

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

GATE="$REPO_ROOT/benches/test_perf_budgets.sh"
PROBE="instant_dot_version"
PROBE_BUDGET_MS=500

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A CLI whose cost is nothing but bash spawns, like the gates that flaked.
cat >"$work/cli.sh" <<'EOF'
n="${SYNTH_SPAWNS:-40}"
i=0
while [ "$i" -lt "$n" ]; do
  bash --noprofile --norc -c 'x=$(printf ok)' || exit 1
  i=$((i + 1))
done
EOF

# The slow runner: every bash start costs an extra bash start.
real_bash="$(command -v bash)"
mkdir -p "$work/slow"
cat >"$work/slow/bash" <<EOF
#!/bin/sh
"$real_bash" --noprofile --norc -c :
exec "$real_bash" "\$@"
EOF
chmod +x "$work/slow/bash"

# _pass [bench-name] — on success, echo that run's calibration and probe lines
# so the log shows the factor and medians each verdict rests on.
_pass() {
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  [[ -n "${1:-}" ]] && grep -E "$PROBE" "$work/$1.out" | sed 's/^/        | /'
  return 0
}

_fail() {
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "$1"
  [[ -f "${2:-}" ]] && sed 's/^/        | /' "$2"
  return 0
}

# _bench <name> [VAR=value...] — run the probe gate; output in $work/<name>.out,
# exit status in $work/<name>.rc.
_bench() {
  local name="$1" rc=0
  shift
  env PERF_GATE_FILTER="$PROBE" DOT_CLI="$work/cli.sh" "$@" \
    bash "$GATE" >"$work/$name.out" 2>&1 || rc=$?
  printf '%s' "$rc" >"$work/$name.rc"
}

_rc() { cat "$work/$1.rc"; }

# The probe gate's median, in ms, from a bench output.
_probe_median() {
  sed -n "s/.*$PROBE: median=\([0-9][0-9]*\)ms.*/\1/p" "$work/$1.out" | head -1
}

# _min_num <a> <b> — the smaller of two numbers; an empty or non-numeric
# side never wins.
_min_num() {
  if [[ ! "$2" =~ ^[0-9]+$ ]]; then
    printf '%s' "$1"
  elif [[ ! "$1" =~ ^[0-9]+$ ]] || [[ "$2" -lt "$1" ]]; then
    printf '%s' "$2"
  else
    printf '%s' "$1"
  fi
}

# ---------------------------------------------------------------------------
# Baseline on this machine, unslowed: the gated command's median (base_ms)
# and the calibration's per-spawn cost (base_us), each the minimum of three
# runs. Every scenario below is scaled from them, and a load spike during a
# single baseline run (the parallel test runner of a pre-push audit) inflated
# both: the regression budget then absorbed a 3x slower command, and the cap
# scenario's reference left the runner under the cap. Load only adds time,
# so the minimum is the reading it cannot inflate.
# ---------------------------------------------------------------------------
_check_baseline() {
  local i
  for i in 1 2 3; do
    _bench "base$i"
    base_ms="$(_min_num "$base_ms" "$(_probe_median "base$i")")"
    base_us="$(_min_num "$base_us" \
      "$(sed -n 's/.*per_spawn=\([0-9][0-9]*\)us.*/\1/p' "$work/base$i.out" | head -1)")"
  done

  test_start "bench_reports_runner_factor"
  if [[ -n "$base_us" ]] && grep -q 'runner=[0-9]*\.[0-9][0-9]x' "$work/base1.out"; then
    _pass base1
  else
    _fail "no runner factor in the gate's output" "$work/base1.out"
  fi

  test_start "baseline_measured"
  if [[ "$base_ms" =~ ^[0-9]+$ ]] && [[ "$base_ms" -ge 4 ]]; then
    _pass
  else
    _fail "no usable probe median (got '${base_ms}')" "$work/base1.out"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# 1. A slow runner fails the uncalibrated budget but passes the gate.
# ---------------------------------------------------------------------------
_check_slow_runner() {
  local slow_ms
  _bench slow_runner "${slow[@]}"
  slow_ms="$(_probe_median slow_runner)"

  test_start "slow_runner_breaks_the_uncalibrated_budget"
  if [[ "$slow_ms" =~ ^[0-9]+$ ]] && [[ "$slow_ms" -gt "$plain_budget" ]]; then
    _pass
  else
    _fail "slow runner median '${slow_ms}'ms is within ${plain_budget}ms — the scenario proves nothing" \
      "$work/slow_runner.out"
  fi

  test_start "slow_runner_passes_the_calibrated_gate"
  if [[ "$(_rc slow_runner)" -eq 0 ]]; then
    _pass slow_runner
  else
    _fail "unchanged code failed on a slow runner (base ${base_ms}ms, budget ${plain_budget}ms)" \
      "$work/slow_runner.out"
  fi
}

# ---------------------------------------------------------------------------
# 2. Tripling the gated command's cost on the same slow runner still fails:
# twice past its 1.5x headroom. A 2x regression clears that headroom by only
# 1.33x, which is inside the run-to-run spread of the factor on a loaded
# machine (2.40x and 3.75x for identical consecutive runs), so it passed once
# in three there; that is the headroom doing its job, not calibration
# absorbing the regression.
# ---------------------------------------------------------------------------
_check_regression() {
  _bench regression "${slow[@]}" SYNTH_SPAWNS=120

  test_start "regression_fails_on_a_slow_runner"
  if [[ "$(_rc regression)" -ne 0 ]] && grep -q "$PROBE: median=.*EXCEEDS" "$work/regression.out"; then
    _pass regression
  else
    _fail "a 3x slower command passed — calibration absorbed a regression" "$work/regression.out"
  fi
}

# ---------------------------------------------------------------------------
# 3. A runner far beyond the cap fails the run, with the reason, even though
# the gated command itself is within its strict, unscaled budget.
# ---------------------------------------------------------------------------
_check_cap() {
  _bench beyond_cap PERF_CALIBRATION_REF_US="$(((base_us + 15) / 16))"

  test_start "runner_beyond_cap_fails_loudly"
  if [[ "$(_rc beyond_cap)" -ne 0 ]] && grep -q 'exceeds the .*x cap' "$work/beyond_cap.out"; then
    _pass beyond_cap
  else
    _fail "a runner 16x slower than the reference did not fail the run" "$work/beyond_cap.out"
  fi
}

_summary() {
  printf '\n  Tests: %d  Passed: %d  Failed: %d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
}

base_ms=""
base_us=""
if ! _check_baseline; then
  _summary
  exit 1
fi
# Old code prints no per-spawn cost; 1 keeps the arithmetic below valid there.
base_us="${base_us:-1}"

# Budget at 1.5x this machine's median: headroom, as every budget carries.
pct=$(((150 * base_ms + PROBE_BUDGET_MS - 1) / PROBE_BUDGET_MS))
plain_budget=$((PROBE_BUDGET_MS * pct / 100))
# The slow runner is set against a reference of twice this machine's cost,
# with twice the budget percent: the same budgets, but the factor reads half
# the slowdown. Without that, load on a shared machine on top of the stub's
# ~2.5x pushed it past the 4x cap (seen once, at 4.14x), and the cap has its
# own scenario below.
slow=(PATH="$work/slow:$PATH" PERF_BUDGET_PERCENT="$((2 * pct))"
  PERF_CALIBRATION_REF_US="$((2 * base_us))")

_check_slow_runner
_check_regression
_check_cap
_summary
exit "$TESTS_FAILED"
