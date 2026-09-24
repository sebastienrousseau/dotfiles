#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
# Only the scorecard reports a finding through its exit code (not perfect ->
# rc=1); security-score, perf, conflicts and locks exit 0 whenever they
# complete. Each row pins the code its command deterministically produces in
# the sandbox and asserts on the shape of the output, since the scores
# themselves depend on the host.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# The scorecard commands are slow by nature; this is a hang guard, not a
# performance gate.
FM_TIMEOUT=150

test_fm_security_score() {
  # security-score never encodes the score in its exit status (that is the
  # scorecard's job): it exits 0 whenever the assessment completes. The score
  # itself depends on the host, so the contract is the report's shape.
  test_start "fm_security_score"
  fm_run security-score
  fm_expect_rc 0
  test_start "fm_security_score_reports_per_check_points"
  fm_expect_out_matches '\([0-9]+/[0-9]+ pts\)'
  test_start "fm_security_score_reports_a_grade"
  fm_expect_out_matches 'Score: .* [0-9]+%  Grade: [A-F][+-]?'
  test_start "fm_security_score_reports_points_out_of_100"
  fm_expect_out_matches 'Points: [0-9]+/100'
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
  fm_expect_rc 0
  test_start "fm_security_score_quiet_keeps_the_summary"
  fm_expect_out_matches 'Points: [0-9]+/100'
  # -q is "no per-check lines", not "no output": the bullets go, the grade
  # stays.
  test_start "fm_security_score_quiet_drops_per_check_lines"
  if printf '%s' "$FM_OUT" | grep -Eq '\([0-9]+/[0-9]+ pts\)'; then
    fm_fail "-q still printed per-check point lines"
  else
    fm_pass "no per-check lines"
  fi
  test_start "fm_security_score_quiet_no_breakage"
  fm_expect_no_forbidden
}

test_fm_score() {
  # The scorecard signals "not perfect" with rc=1. In the sandbox that is the
  # only reachable outcome: HOME has no SSH key, so the security score can
  # never reach 100 — and the row ties the rc to the reason the report gives.
  test_start "fm_score"
  fm_run score
  fm_expect_rc 1
  test_start "fm_score_renders_scorecard"
  fm_expect_out "Dotfiles Scorecard"
  test_start "fm_score_reports_health"
  fm_expect_out_matches 'Health +[0-9]+/100'
  test_start "fm_score_reports_security"
  fm_expect_out_matches 'Security +[0-9]+/100'
  test_start "fm_score_explains_the_nonzero_exit"
  fm_expect_out "Run 'dot security-score' to reach 100/100"
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
  # A report, not a gate: conflicts are listed, never turned into an exit
  # code, so a completed run is rc=0 regardless of what it found.
  fm_expect_rc 0
  test_start "fm_conflicts_reports"
  fm_expect_out "Alias & Command Conflicts"
  test_start "fm_conflicts_checks_duplicates"
  fm_expect_out "Duplicate alias definitions"
  test_start "fm_conflicts_checks_shadowing"
  fm_expect_out "Alias shadows real commands"
  test_start "fm_conflicts_runs_to_completion"
  fm_expect_out "Quick actions"
}

test_fm_locks() {
  test_start "fm_locks"
  fm_run locks
  fm_expect_rc 0
  test_start "fm_locks_reports_toolchain"
  fm_expect_out "Version Locks"
  # A tool/version row proves the mise [tools] table was found AND parsed.
  # After the defaults/ reorg this silently printed "config not found" on
  # every machine while still exiting 0, which is what the next two pin.
  test_start "fm_locks_parses_the_mise_pins"
  fm_expect_out_matches '^  (node|python|go|ruby|java) +[^ ]'
  test_start "fm_locks_finds_the_mise_config"
  if [[ "$FM_OUT" == *"config not found"* ]]; then
    fm_fail "mise config not resolved from the source tree"
  else
    fm_pass
  fi
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
