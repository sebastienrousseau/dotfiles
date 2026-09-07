#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the scoring and profiling commands —
# security-score, score, scorecard, perf, conflicts and locks.
#
# Split out of test_feature_matrix_diagnostics.sh. Each of the three scorecard
# entry points re-runs health + security-score + perf underneath (~13s each on
# the reference machine), which pushed that file past the 180s per-suite
# budget tests/regression/test_test_framework_invariants.sh allows when it
# re-runs each suite to check the RUN == PASSED + FAILED invariant.
#
# These commands report a finding through their exit code — a scorecard that
# is not perfect exits 1 — so the rows assert on the shape of the output and
# accept either code.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# The scorecard commands are slow by nature; this is a hang guard, not a
# performance gate.
FM_TIMEOUT=150

test_fm_security_score() {
  test_start "fm_security_score"
  fm_run security-score
  fm_expect_rc_in 0 1
  test_start "fm_security_score_reports"
  fm_expect_any "Security Score" "Encryption"
}

test_fm_security_score_json() {
  test_start "fm_security_score_json"
  fm_run security-score -j
  fm_expect_rc_in 0 1
  test_start "fm_security_score_json_is_json"
  fm_expect_json
  test_start "fm_security_score_json_has_grade"
  fm_expect_out '"grade"'
}

test_fm_security_score_quiet() {
  test_start "fm_security_score_quiet"
  fm_run security-score -q
  fm_expect_rc_in 0 1
  test_start "fm_security_score_quiet_no_breakage"
  fm_expect_no_forbidden
}

test_fm_score() {
  test_start "fm_score"
  fm_run score
  fm_expect_rc_in 0 1
  test_start "fm_score_renders_scorecard"
  fm_expect_any "Scorecard" "Health"
}

test_fm_score_json() {
  test_start "fm_score_json"
  fm_run score --json
  fm_expect_rc_in 0 1
  test_start "fm_score_json_is_json"
  fm_expect_json
  test_start "fm_score_json_has_health"
  fm_expect_out '"health"'
}

test_fm_scorecard() {
  test_start "fm_scorecard"
  fm_run scorecard --json
  fm_expect_rc_in 0 1
  test_start "fm_scorecard_is_alias_of_score"
  fm_expect_out '"health"'
}

test_fm_perf_json() {
  test_start "fm_perf_json"
  fm_run perf -j -r 1
  fm_expect_rc_in 0 1
  test_start "fm_perf_json_is_json"
  fm_expect_json
  test_start "fm_perf_json_has_shells"
  fm_expect_out '"shells"'
}

test_fm_perf_profile() {
  # --target changes the pass/fail threshold the JSON reports back, which is
  # the cheapest way to prove the flag is parsed rather than ignored.
  test_start "fm_perf_profile"
  fm_run perf -j -r 1 -t 999
  fm_expect_rc_in 0 1
  test_start "fm_perf_profile_honours_target"
  fm_expect_out '"target_ms": 999'
}

test_fm_conflicts() {
  test_start "fm_conflicts"
  fm_run conflicts
  fm_expect_rc_in 0 1
  test_start "fm_conflicts_reports"
  fm_expect_any "Conflicts" "conflict" "Alias"
}

test_fm_locks() {
  test_start "fm_locks"
  fm_run locks
  fm_expect_rc_in 0 1
  test_start "fm_locks_reports_toolchain"
  fm_expect_any "Version Locks" "mise"
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: scoring and profiling ──"
echo ""

test_fm_security_score
test_fm_security_score_json
test_fm_security_score_quiet
test_fm_score
test_fm_score_json
test_fm_scorecard
test_fm_perf_json
test_fm_perf_profile
test_fm_conflicts
test_fm_locks

fm_finish
