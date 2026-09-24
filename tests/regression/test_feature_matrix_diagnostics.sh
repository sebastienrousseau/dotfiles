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
# Two of these commands report a *finding* through their exit code: doctor
# exits 1 when any probe errors and the scorecard exits 1 unless health and
# security both score 100. Both probe the runner's toolchain, which the
# sandbox does not control, so only those rows keep fm_expect_rc_in and each
# says what varies. Every other row pins the exact code the sandbox produces.
# Every row also asserts on output the command must emit: a row that accepts
# both 0 and 1 with no output check passes whether the command works or
# fails, and protects nothing.

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

# fm_expect_config_unchanged <before> — a dry run must leave $HOME/.config
# exactly as it found it. <before> is the `ls -A | sort` listing taken before
# the run.
fm_expect_config_unchanged() {
  local after
  after="$(ls -A "$HOME/.config" 2>/dev/null | sort)"
  if [[ "$1" == "$after" ]]; then
    fm_pass "\$HOME/.config untouched"
  else
    fm_fail "dry run changed \$HOME/.config"
  fi
}

# ── doctor ─────────────────────────────────────────────────────────────────

test_fm_doctor() {
  test_start "fm_doctor"
  fm_run doctor
  # doctor.sh exits 1 when any probe errors, and its probes read the host:
  # which tools resolve on PATH, whether the pueue daemon is up, which shells
  # are installed. The sandbox owns HOME, not the runner's toolbox.
  fm_expect_rc_in 0 1
  test_start "fm_doctor_reports_sections"
  fm_expect_out "--- Dotfiles Doctor ---"
  test_start "fm_doctor_probes_core_shells"
  fm_expect_out "== Core Shells =="
  test_start "fm_doctor_prints_verdict"
  fm_expect_out_matches 'Healthy +(All checks passed|[0-9]+ warning)|[0-9]+ error\(s\) +[0-9]+ warning'
}

test_fm_doctor_score() {
  test_start "fm_doctor_score"
  fm_run doctor --score
  # scorecard.sh exits 1 unless health and security both reach 100, and both
  # scores come from the host's installed tools and key material.
  fm_expect_rc_in 0 1
  test_start "fm_doctor_score_renders_scorecard"
  fm_expect_out "--- Dotfiles Scorecard ---"
  test_start "fm_doctor_score_reports_health_out_of_100"
  fm_expect_out_matches 'Health +[0-9]+/100'
  test_start "fm_doctor_score_reports_security_out_of_100"
  fm_expect_out_matches 'Security +[0-9]+/100'
}

test_fm_doctor_smoke() {
  test_start "fm_doctor_smoke"
  fm_run doctor --smoke
  # Deterministic in the sandbox: the chezmoi shim prints nothing for
  # --version, so smoke-test.sh must flag it as "output mismatch" and exit
  # 1. That is the property worth pinning — the smoke test checks what a
  # tool says, not merely that it resolves.
  fm_expect_rc 1
  test_start "fm_doctor_smoke_runs_smoke_tests"
  fm_expect_out "--- Dotfiles Smoke Tests ---"
  test_start "fm_doctor_smoke_flags_the_silent_chezmoi_shim"
  fm_expect_out_matches 'chezmoi +output mismatch'
  test_start "fm_doctor_smoke_summarises_failures"
  fm_expect_out_matches '[0-9]+ failed +[0-9]+ passed'
}

test_fm_doctor_drift() {
  test_start "fm_doctor_drift"
  fm_run doctor --drift
  # The chezmoi shim reports no status and no source path, and the orphan
  # list lives under the sandboxed XDG_STATE_HOME, so every drift class is
  # empty and the dashboard exits 0.
  fm_expect_rc 0
  test_start "fm_doctor_drift_renders_dashboard"
  fm_expect_out "--- Dotfiles Drift Dashboard ---"
  test_start "fm_doctor_drift_finds_nothing_in_the_sandbox"
  fm_expect_out "no drift detected"
}

test_fm_doctor_heal() {
  # --heal routes to the heal script; --dry-run rides along so nothing is
  # repaired for real.
  local before
  before="$(ls -A "$HOME/.config" 2>/dev/null | sort)"
  test_start "fm_doctor_heal"
  fm_run doctor --heal --dry-run
  fm_expect_rc 0
  test_start "fm_doctor_heal_routes_to_heal"
  fm_expect_out "Dotfiles Heal"
  test_start "fm_doctor_heal_announces_dry_run"
  fm_expect_out "Dry-run mode (no changes will be made)"
  test_start "fm_doctor_heal_lists_what_it_would_do"
  # The shim never applies anything, so the sandbox HOME always has managed
  # files missing for heal to offer to regenerate.
  fm_expect_out_matches 'DRY-RUN +Would: '
  test_start "fm_doctor_heal_dry_run_changes_nothing"
  fm_expect_config_unchanged "$before"
}

test_fm_doctor_audit() {
  # --audit used to map to scripts/ops/health-check.sh, which has never been
  # in the tree, so the flag died with "Script not found". It now routes to
  # the health dashboard — the audit-shaped diagnostic the name meant.
  test_start "fm_doctor_audit"
  fm_run doctor --audit
  # health.sh reports failures in its summary, never through its exit code.
  fm_expect_rc 0
  test_start "fm_doctor_audit_is_routed"
  fm_expect_out "Dotfiles Health Dashboard"
  test_start "fm_doctor_audit_target_exists"
  if [[ "$FM_OUT$FM_ERR" == *"Script not found"* ]]; then
    fm_fail "--audit routes to a script that is not in the tree"
  else
    fm_pass "the target resolved"
  fi
  test_start "fm_doctor_audit_prints_summary"
  fm_expect_out_matches 'Total checks: +[0-9]+'
}

test_fm_doctor_json() {
  test_start "fm_doctor_json"
  fm_run doctor --json
  # Same host verdict as the bare doctor row, rendered as one JSON document
  # in the shape of `dot health --json` (total/passed/warnings/failures/
  # results) plus status and verdict. The exit code is the same signal as
  # the text dashboard's, so status must agree with it.
  fm_expect_rc_in 0 1
  test_start "fm_doctor_json_is_json"
  fm_expect_json
  test_start "fm_doctor_json_has_status"
  fm_expect_out_matches '"status": "(healthy|unhealthy)"'
  test_start "fm_doctor_json_status_matches_exit_code"
  if { [[ "$FM_RC" -eq 0 && "$FM_OUT" == *'"status": "healthy"'* ]] ||
    [[ "$FM_RC" -eq 1 && "$FM_OUT" == *'"status": "unhealthy"'* ]]; }; then
    fm_pass "rc=$FM_RC"
  else
    fm_fail "status and rc=$FM_RC disagree"
  fi
  test_start "fm_doctor_json_has_verdict"
  fm_expect_out '"verdict": "'
  test_start "fm_doctor_json_counts_checks"
  fm_expect_out_matches '"total": [1-9][0-9]*,'
  test_start "fm_doctor_json_counts_failures"
  fm_expect_out_matches '"failures": [0-9]+,'
  test_start "fm_doctor_json_counts_warnings"
  fm_expect_out_matches '"warnings": [0-9]+,'
  test_start "fm_doctor_json_lists_results"
  fm_expect_out_matches '"check":"zsh","status":"(pass|fail)"'
  test_start "fm_doctor_json_drops_the_dashboard"
  if [[ "$FM_OUT" == *"--- Dotfiles Doctor ---"* ]]; then
    fm_fail "the text dashboard leaked into the JSON output"
  else
    fm_pass "stdout is the document only"
  fi
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
  # heal.sh guards every repair with `|| true` and exits 0 whether or not it
  # could fix anything; the summary line is what carries the result.
  fm_expect_rc 0
  test_start "fm_heal_reports"
  fm_expect_out "Dotfiles Heal"
  test_start "fm_heal_checks_dependencies"
  fm_expect_out "== Checking dependencies =="
  test_start "fm_heal_creates_missing_xdg_dirs"
  # heal_missing_xdg_dirs creates ~/.config/{shell,nvim,git}; nothing earlier
  # in this file creates them, so this is the first repair to land.
  fm_expect_file "$HOME/.config/nvim"
  test_start "fm_heal_summarises"
  fm_expect_out_matches 'Applied [0-9]+ fix\(es\) for [0-9]+ issue\(s\)|Healthy\.'
}

test_fm_heal_dry_run() {
  local before
  before="$(ls -A "$HOME/.config" 2>/dev/null | sort)"
  test_start "fm_heal_dry_run"
  fm_run heal --dry-run
  fm_expect_rc 0
  test_start "fm_heal_dry_run_announces_dry_run"
  fm_expect_out "Dry-run mode (no changes will be made)"
  test_start "fm_heal_dry_run_lists_what_it_would_do"
  fm_expect_out_matches 'DRY-RUN +Would: '
  test_start "fm_heal_dry_run_changes_nothing"
  fm_expect_config_unchanged "$before"
}

test_fm_health() {
  test_start "fm_health"
  fm_run health
  fm_expect_rc 0
  test_start "fm_health_renders_dashboard"
  fm_expect_out "Dotfiles Health Dashboard"
  test_start "fm_health_prints_summary"
  fm_expect_out_matches 'Total checks: +[0-9]+'
  test_start "fm_health_prints_score"
  fm_expect_out_matches 'Health Score: .*[0-9]+%'
}

test_fm_health_json() {
  test_start "fm_health_json"
  fm_run health -j
  fm_expect_rc 0
  test_start "fm_health_json_is_json"
  fm_expect_json
  test_start "fm_health_json_has_score"
  fm_expect_out '"score"'
  test_start "fm_health_json_has_results"
  fm_expect_out '"results"'
}

test_fm_health_verbose() {
  test_start "fm_health_verbose"
  fm_run health -v
  fm_expect_rc 0
  test_start "fm_health_verbose_renders_dashboard"
  fm_expect_out "Dotfiles Health Dashboard"
  test_start "fm_health_verbose_prints_summary"
  fm_expect_out_matches 'Total checks: +[0-9]+'
}

test_fm_health_check_alias() {
  test_start "fm_health_check_alias"
  fm_run health-check -j
  fm_expect_rc 0
  test_start "fm_health_check_alias_is_json"
  fm_expect_json
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
