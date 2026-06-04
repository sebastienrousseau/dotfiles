#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: the test runner must produce the same totals whether
# run serially (--jobs 1) or in parallel (--jobs auto).
#
# Anti-pattern guard: if a future test file develops order-coupling
# (writes a marker file at test-start that another file expects to be
# in a specific state), this test will catch it because the two runs
# will diverge in pass/fail counts.
#
# Skips itself when REPO_ROOT can't reach the runner; tolerates the
# `set -euo pipefail` outer-shell context that wraps assertions.
#
# Regression for: GH-867
# Why: Parallelism is a new behavior; without an invariance test,
# silent order-coupling could grow back over time.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# shellcheck source=../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

RUNNER="$REPO_ROOT/tests/framework/test_runner.sh"

# Pick a small, stable subset to keep the regression cheap. The
# secrets domain has 5 files, takes ~2 seconds, and exercises both
# normal-pass and skipped paths.
PATTERN="secrets_*"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "runner_exists"
assert_file_exists "$RUNNER" "test runner should exist"

test_start "runner_supports_jobs_flag"
assert_file_contains "$RUNNER" -- "--jobs" "runner must accept --jobs"

test_start "runner_supports_jobs_auto"
assert_file_contains "$RUNNER" -- "auto)" "runner must accept --jobs auto"

# -----------------------------------------------------------------------------
# Behavioural: serial vs parallel must agree
# -----------------------------------------------------------------------------

extract_totals() {
  # Parse the final-summary block. Returns "run:passed:failed" on stdout.
  awk '
    /Total tests run:/  { run = $NF }
    /Total passed:/     { passed = $NF; gsub(/\x1b\[[0-9;]*m/, "", passed) }
    /Total failed:/     { failed = $NF; gsub(/\x1b\[[0-9;]*m/, "", failed) }
    END                 { printf "%s:%s:%s\n", run, passed, failed }
  ' "$1"
}

set +e
serial_out=$(mktemp)
parallel_out=$(mktemp)
bash "$RUNNER" --jobs 1 "$PATTERN" > "$serial_out" 2>&1
serial_rc=$?
bash "$RUNNER" --jobs auto "$PATTERN" > "$parallel_out" 2>&1
parallel_rc=$?
set -e

serial_totals=$(extract_totals "$serial_out")
parallel_totals=$(extract_totals "$parallel_out")

test_start "serial_run_succeeds"
if [[ $serial_rc -eq 0 ]]; then
  assert_exit_code 0 "true"
else
  echo "Serial output (last 20 lines):" >&2
  tail -20 "$serial_out" >&2
  assert_exit_code 0 "false  # serial run exited $serial_rc"
fi

test_start "parallel_run_succeeds"
if [[ $parallel_rc -eq 0 ]]; then
  assert_exit_code 0 "true"
else
  echo "Parallel output (last 20 lines):" >&2
  tail -20 "$parallel_out" >&2
  assert_exit_code 0 "false  # parallel run exited $parallel_rc"
fi

test_start "totals_match_under_reordering"
if [[ "$serial_totals" == "$parallel_totals" ]]; then
  assert_exit_code 0 "true"
else
  echo "Serial:   $serial_totals" >&2
  echo "Parallel: $parallel_totals" >&2
  assert_exit_code 0 "false  # totals differ — possible test-order coupling"
fi

test_start "totals_are_nonzero"
# Sanity check: if the runner is silently doing nothing, both totals are
# 0:0:0 which would pass the equality check above but mean we ran no
# tests at all.
if [[ "$serial_totals" != "0:0:0" ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # both runs reported zero tests — bad pattern '$PATTERN'?"
fi

rm -f "$serial_out" "$parallel_out"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
