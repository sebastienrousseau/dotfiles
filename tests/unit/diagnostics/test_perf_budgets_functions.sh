#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# benches/test_perf_budgets.sh: the paths a real run rarely takes. An
# unparseable clock, a failed calibration sample, non-numeric measurements
# and a runner exactly at the factor cap each decide whether a gate passes,
# and none of them can be produced by timing real commands on demand.
# The bench is sourced for its functions (it stops before the first gate)
# and the clock or the measurement is stubbed per case.
#
# AUTO-GENERATED: false (hand-written)

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
GATE="$REPO_ROOT/benches/test_perf_budgets.sh"

# The bench sources the assertions framework itself.
if ! source "$GATE"; then
  printf 'sourcing %s failed\n' "$GATE"
  exit 1
fi

# ---------------------------------------------------------------------------
test_start "calibration_reference_must_be_a_positive_integer"
for ref in 05 x5800; do
  out="$(PERF_CALIBRATION_REF_US="$ref" bash "$GATE" 2>&1)"
  assert_equals 2 "$?" "PERF_CALIBRATION_REF_US=$ref exits 2"
  assert_contains "must be a positive integer (got $ref)" "$out" "and names the bad value"
done

# ---------------------------------------------------------------------------
# The timed command runs inside _time_once, so a shell function sees its
# local TIMEFORMAT and can make the clock print something that is not a time.
_garble_clock() { TIMEFORMAT='x%3R'; }

test_start "time_once_refuses_an_unparseable_clock"
out="$(_time_once _garble_clock)"
assert_equals 1 "$?" "an unparseable reading returns 1"
assert_contains "CLOCK_UNUSABLE x" "$out" "and reports the raw reading"

test_start "time_once_reports_status_and_ms"
out="$(_time_once false)"
assert_equals 0 "$?" "a parseable reading returns 0"
shape=other
[[ "$out" =~ ^1\ [0-9]+$ ]] && shape="<status> <ms>"
assert_equals "<status> <ms>" "$shape" "and prints '<status> <ms>' (got '$out')"

# ---------------------------------------------------------------------------
# _measure: what goes wrong is reported in its output, and it still returns
# 0. The calibration sample is told apart by its workload argument.
CALIBRATION_WORKLOAD="$HOME/perf-calibration-workload.sh"
_time_once() {
  if [[ "${2:-}" == "$CALIBRATION_WORKLOAD" ]]; then
    printf '%s' "$STUB_CAL"
    return "$STUB_CAL_RC"
  fi
  printf '%s' "$STUB_CMD"
  return "$STUB_CMD_RC"
}

test_start "measure_reports_an_unusable_calibration_clock"
STUB_CAL="CLOCK_UNUSABLE cal" STUB_CAL_RC=1 STUB_CMD="0 10" STUB_CMD_RC=0
out="$(_measure 1 true)"
assert_equals 0 "$?" "_measure returns 0"
assert_equals "CLOCK_UNUSABLE cal" "$out" "with the calibration's reading as its output"

test_start "measure_reports_an_unusable_command_clock"
STUB_CAL="0 100" STUB_CAL_RC=0 STUB_CMD="CLOCK_UNUSABLE cmd" STUB_CMD_RC=1
out="$(_measure 1 true)"
assert_equals 0 "$?" "_measure returns 0"
assert_equals "CLOCK_UNUSABLE cmd" "$out" "with the command's reading as its output"

test_start "measure_prints_worst_status_and_medians"
STUB_CAL="0 100" STUB_CAL_RC=0 STUB_CMD="1 10" STUB_CMD_RC=0
assert_equals "1 10 100" "$(_measure 3 true)" "worst status, command median, calibration median"

# ---------------------------------------------------------------------------
# _gate_max_rc and _budget_verdict count results themselves, so each runs in
# a command substitution and leaves this file's counters alone.
_measure() { printf '%s' "$STUB_MEASURE"; }

test_start "gate_refuses_a_non_numeric_status"
out="$(STUB_MEASURE="-0 100 100" _gate_max_rc 0 probe 500 1 true)"
assert_contains "could not measure (got -0 100 100)" "$out" "a signed status is not a measurement"

test_start "gate_refuses_a_non_numeric_calibration"
out="$(STUB_MEASURE="0 100 -3000" _gate_max_rc 0 probe 500 1 true)"
assert_contains "could not measure (got 0 100 -3000)" "$out" "a signed calibration is not a measurement"

test_start "median_equal_to_the_budget_passes"
CALIBRATION_REF_US=5800
out="$(_budget_verdict probe 500 500 30)"
assert_contains "probe: median=500ms budget=500ms" "$out" "the budget is inclusive"
passed=no
[[ "$out" == *"✓"* ]] && passed=yes
assert_equals yes "$passed" "and the gate passes"

# 30 spawns in 120 ms is 4000 us each: 4.00x a 1000 us reference, the cap.
test_start "runner_at_the_cap_still_gates"
CALIBRATION_REF_US=1000
out="$(_budget_verdict probe 500 100 120)"
assert_contains "median=100ms budget=2000ms (runner=4.00x" "$out" "4.00x scales the budget"
refused=no
[[ "$out" == *"cap"* ]] && refused=yes
assert_equals no "$refused" "and is not refused at the cap"

test_start "runner_past_the_cap_is_refused"
out="$(_budget_verdict probe 500 100 121)"
assert_contains "runner=4.03x per_spawn=4033us reference=1000us exceeds the 4.00x cap" "$out" \
  "4.03x fails and says why"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
