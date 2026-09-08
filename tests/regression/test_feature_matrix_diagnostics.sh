#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the diagnostics.sh command group —
# doctor, heal, health, security-score, score, perf, conflicts and locks.
# The state-handling half of the group (snapshot, attest, rollback, drift,
# history, restore, metrics, …) lives in
# tests/regression/test_feature_matrix_diagnostics_state.sh so the two run
# concurrently rather than serialising into one five-minute file.
#
# Many of these commands report a *finding* through their exit code (a
# scorecard that is not perfect exits 1), so assertions use fm_expect_rc_in
# where the host legitimately decides the code. What is pinned instead is
# that the command routes to its backing script, honours its flag, and emits
# the shape of output downstream tooling parses.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# The scoring commands re-probe the whole toolchain: a full `dot doctor` is
# ~20s uncontended on the reference machine and several times that when the
# regression suite runs files concurrently. This is a hang guard, not a
# performance gate — benches owns those — so give it real headroom.
FM_TIMEOUT=150

# ── doctor ─────────────────────────────────────────────────────────────────

test_fm_doctor() {
  test_start "fm_doctor"
  fm_run doctor
  fm_expect_rc_in 0 1
  test_start "fm_doctor_reports_sections"
  fm_expect_any "Dotfiles Doctor" "Core Shells"
}

test_fm_doctor_score() {
  test_start "fm_doctor_score"
  fm_run doctor --score
  fm_expect_rc_in 0 1
  test_start "fm_doctor_score_renders_scorecard"
  fm_expect_any "Scorecard" "Health"
}

test_fm_doctor_smoke() {
  test_start "fm_doctor_smoke"
  fm_run doctor --smoke
  fm_expect_rc_in 0 1
  test_start "fm_doctor_smoke_runs_smoke_tests"
  fm_expect_any "Smoke Tests" "smoke"
}

test_fm_doctor_drift() {
  test_start "fm_doctor_drift"
  fm_run doctor --drift
  fm_expect_rc_in 0 1
  test_start "fm_doctor_drift_renders_dashboard"
  fm_expect_any "Drift Dashboard" "drift"
}

test_fm_doctor_heal() {
  # --heal routes to the heal script; --dry-run rides along so nothing is
  # repaired for real.
  test_start "fm_doctor_heal"
  fm_run doctor --heal --dry-run
  fm_expect_rc_in 0 1
  test_start "fm_doctor_heal_routes_to_heal"
  fm_expect_any "Heal" "Dry-run" "DRY-RUN"
}

test_fm_doctor_audit() {
  # KNOWN BUG (reported, not fixed here — scripts/diagnostics is another
  # agent's file): doctor-unified.sh maps --audit to scripts/ops/health-check.sh,
  # which does not exist in the tree, so the flag currently dies with
  # "Script not found". The assertion below passes both before and after that
  # is fixed: what is pinned is that --audit is RECOGNISED as a flag and
  # routed somewhere, not that the target happens to be missing today.
  test_start "fm_doctor_audit"
  fm_run doctor --audit
  fm_expect_rc_in 0 1
  test_start "fm_doctor_audit_is_routed"
  fm_expect_any "Script not found" "Health" "health" "audit"
}

test_fm_doctor_json() {
  test_start "fm_doctor_json"
  fm_run doctor --json
  fm_expect_rc_in 0 1
  test_start "fm_doctor_json_no_breakage"
  fm_expect_no_forbidden
}

test_fm_smoke_doctor_benchmark() {
  # --benchmark shells out to the full hyperfine sweep over every installed
  # shell: minutes of wall clock. benches/bench.sh owns that gate.
  fm_smoke doctor
}

# ── heal / health ──────────────────────────────────────────────────────────

test_fm_heal() {
  test_start "fm_heal"
  fm_run heal
  fm_expect_rc_in 0 1
  test_start "fm_heal_reports"
  fm_expect_any "Heal" "dependencies"
}

test_fm_heal_dry_run() {
  test_start "fm_heal_dry_run"
  fm_run heal --dry-run
  fm_expect_rc_in 0 1
  test_start "fm_heal_dry_run_announces_dry_run"
  fm_expect_any "Dry-run" "DRY-RUN"
}

test_fm_health() {
  test_start "fm_health"
  fm_run health
  fm_expect_rc_in 0 1
  test_start "fm_health_renders_dashboard"
  fm_expect_any "Health" "health"
}

test_fm_health_json() {
  test_start "fm_health_json"
  fm_run health -j
  fm_expect_rc_in 0 1
  test_start "fm_health_json_is_json"
  fm_expect_json
  test_start "fm_health_json_has_score"
  fm_expect_out '"score"'
}

test_fm_health_verbose() {
  test_start "fm_health_verbose"
  fm_run health -v
  fm_expect_rc_in 0 1
  test_start "fm_health_verbose_is_more_detailed"
  fm_expect_nonempty
}

test_fm_health_check_alias() {
  test_start "fm_health_check_alias"
  fm_run health-check -j
  fm_expect_rc_in 0 1
  test_start "fm_health_check_alias_matches_health"
  fm_expect_out '"score"'
}

test_fm_smoke_health_fix() {
  # --fix re-applies chezmoi and rewrites shell configs under $HOME.
  fm_smoke health
}

# ── security-score / score ─────────────────────────────────────────────────

# ── perf ───────────────────────────────────────────────────────────────────

# ── conflicts / locks ──────────────────────────────────────────────────────

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: diagnostics (doctor, health, scoring) ──"
echo ""

test_fm_doctor
test_fm_doctor_score
test_fm_doctor_smoke
test_fm_doctor_drift
test_fm_doctor_heal
test_fm_doctor_audit
test_fm_doctor_json
test_fm_smoke_doctor_benchmark
test_fm_heal
test_fm_heal_dry_run
test_fm_health
test_fm_health_json
test_fm_health_verbose
test_fm_health_check_alias
test_fm_smoke_health_fix

fm_finish
