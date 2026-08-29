#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Wall-clock ratchet for the help / route gate suite.
#
# Two regression tests exercise the dispatcher's static tables end
# to end:
#   * test_dot_subcommand_smoke.sh — routes → backing module + help
#   * test_dot_help_flag_universal.sh — every command answers --help
#
# Their combined runtime is checked here so if either regresses
# (e.g. a new command adds a slow help path or the smoke test starts
# spawning a sandbox per command), CI catches it before the whole
# regression suite balloons.
#
# Threshold: 20000ms across both gate scripts. Baseline on the
# reference machine (2026-08-29): ~1500ms. 13x headroom is
# intentional — CI runners are slower and the sandbox chmod +
# XDG init in the smoke test adds variance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

GATES=(
  tests/regression/test_dot_subcommand_smoke.sh
  tests/regression/test_dot_help_flag_universal.sh
)

THRESHOLD_MS="${HELP_GATES_WALL_CLOCK_MS:-20000}"
PER_GATE_MAX_MS="${HELP_GATES_PER_MAX_MS:-15000}"

test_start "all_gate_files_present"
missing=()
for g in "${GATES[@]}"; do
  [[ -f "$REPO_ROOT/$g" ]] || missing+=("$g")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: missing %s\n' "$CURRENT_TEST" "${missing[*]}"
  printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  exit 1
fi

test_start "gate_pass_rates"
fail_summary=()
for g in "${GATES[@]}"; do
  out="$(bash "$REPO_ROOT/$g" 2>&1 || true)"
  results_line="$(printf '%s\n' "$out" | grep '^RESULTS:' | tail -1)"
  if [[ -z "$results_line" ]]; then
    fail_summary+=("$(basename "$g"): no RESULTS: line")
    continue
  fi
  IFS=: read -r _ _ _ fail <<<"$results_line"
  if (( ${fail:-0} != 0 )); then
    fail_summary+=("$(basename "$g"): $fail failed")
  fi
done
if [[ ${#fail_summary[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: both gates pass\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${fail_summary[*]}"
fi

test_start "total_wall_clock_under_threshold_${THRESHOLD_MS}ms"
start_ns=$(date +%s%N)
for g in "${GATES[@]}"; do
  bash "$REPO_ROOT/$g" >/dev/null 2>&1 || true
done
end_ns=$(date +%s%N)
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
if (( elapsed_ms <= THRESHOLD_MS )); then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: elapsed=%dms\n' "$CURRENT_TEST" "$elapsed_ms"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: elapsed=%dms EXCEEDS threshold=%dms\n' \
    "$CURRENT_TEST" "$elapsed_ms" "$THRESHOLD_MS"
fi

test_start "per_gate_under_${PER_GATE_MAX_MS}ms_each"
slow=()
for g in "${GATES[@]}"; do
  start_ns=$(date +%s%N)
  bash "$REPO_ROOT/$g" >/dev/null 2>&1 || true
  end_ns=$(date +%s%N)
  ms=$(( (end_ns - start_ns) / 1000000 ))
  if (( ms > PER_GATE_MAX_MS )); then
    slow+=("$(basename "$g"):${ms}ms")
  fi
done
if [[ ${#slow[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${slow[*]}"
fi

printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
