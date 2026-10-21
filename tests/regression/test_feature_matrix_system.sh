#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Regression for: GH-881
# Feature matrix: scripts/dot/commands/system.sh, `dot system status` and
# the maintenance schedule (docs/reference/FEATURE-MATRIX.md). launchctl
# and systemctl are `true`, so `set` writes into the sandbox and loads
# nothing.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup
export DOT_LAUNCHCTL=true DOT_SYSTEMCTL=true

test_fm_system_status() {
  test_start "fm_system_status"
  fm_run system
  fm_expect_rc 0
  test_start "fm_system_status_shows_the_schedule"
  fm_expect_out "Schedule   off"
}

test_fm_system_schedule_list() {
  test_start "fm_system_schedule_list"
  fm_run system schedule
  fm_expect_rc 0
  test_start "fm_system_schedule_list_names_the_job"
  fm_expect_out "maintenance"
}

test_fm_system_schedule_set() {
  test_start "fm_system_schedule_set"
  fm_run system schedule set weekly
  fm_expect_rc 0
  test_start "fm_system_schedule_set_reports_it"
  fm_expect_out "Maintenance: weekly"
  test_start "fm_system_schedule_set_rejects_a_bad_word"
  fm_run system schedule set hourly
  fm_expect_rc 2
}

test_fm_system_schedule_run() {
  test_start "fm_system_schedule_run"
  fm_run system schedule run
  fm_expect_rc 0
  test_start "fm_system_schedule_run_is_recorded"
  fm_run system status
  fm_expect_out ", exit 0"
}

test_fm_system_status
test_fm_system_schedule_list
test_fm_system_schedule_set
test_fm_system_schedule_run

print_summary
