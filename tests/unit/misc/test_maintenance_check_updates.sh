#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for check-updates maintenance script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

UPDATE_SCRIPT="$REPO_ROOT/tools/maintenance/check-updates.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "check_updates_script_exists"
assert_file_exists "$UPDATE_SCRIPT" "check-updates.sh should exist"

test_start "check_updates_syntax"
if bash -n "$UPDATE_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# The script reports on the tree it lives in, so each case copies it into
# a scratch tree (its own ci.yml, a stub curl for the GitHub API) and reads
# the report there; nothing touches the network or this checkout.
CU="$DOTFILES_COV_TMPDIR/check-updates"
# cu_run <ci.yml pin line or ""> <latest tag or "" for unreachable>: sets rc,
# err (stderr) and report (updates.txt); the tree persists between runs.
cu_tree() {
  rm -rf "$CU" && mkdir -p "$CU/tools/maintenance" "$CU/.github/workflows" "$CU/bin"
  cp "$UPDATE_SCRIPT" "$CU/tools/maintenance/"
  { [[ -n "$1" ]] && printf 'env:\n  %s\n' "$1"; printf 'jobs:\n  a:\n    steps:\n      - uses: actions/checkout@v4\n'; } >"$CU/.github/workflows/ci.yml"
}
cu_run() {
  if [[ -n "$1" ]]; then
    printf '#!/bin/sh\necho "  \\"tag_name\\": \\"v%s\\","\n' "$1" >"$CU/bin/curl"
  else
    printf '#!/bin/sh\nexit 6\n' >"$CU/bin/curl"
  fi
  chmod +x "$CU/bin/curl"
  rc=0
  PATH="$CU/bin:$PATH" bash "$CU/tools/maintenance/check-updates.sh" >/dev/null 2>"$CU/err" || rc=$?
  err="$(cat "$CU/err")"
  report="$(cat "$CU/nightly-reports/updates.txt" 2>/dev/null)"
}

test_start "check_updates_current_reports_up_to_date"
cu_tree 'CHEZMOI_VERSION: "2.72.2"'
cu_run 2.72.2
assert_equals "0|1|1" "$rc|$(grep -c 'Chezmoi is up to date' <<<"$report")|$(grep -c 'All dependencies appear current' <<<"$report")" "no update: both verdicts, exit 0"

test_start "check_updates_summary_has_no_arithmetic_error"
assert_equals "" "$(grep 'syntax error' <<<"$err")" "the zero-update count is a number"

test_start "check_updates_flags_newer_chezmoi"
cu_run 2.73.0
assert_equals "1|1" "$(grep -c 'update available: 2.72.2 → 2.73.0' <<<"$report")|$(grep -c '1 potential updates found' <<<"$report")" "the newer release is reported and counted"

test_start "check_updates_lists_each_action_once_across_runs"
assert_equals "1" "$(grep -c 'actions/checkout: v4' <<<"$report")" "a second run does not repeat actions"

test_start "check_updates_survives_missing_pin"
cu_tree ""
cu_run 2.72.2
assert_equals "0|1" "$rc|$(grep -c 'Current Chezmoi: unknown' <<<"$report")" "no CHEZMOI_VERSION in ci.yml is reported, not fatal"

test_start "check_updates_survives_unreachable_api"
cu_tree 'CHEZMOI_VERSION: "2.72.2"'
cu_run ""
assert_equals "0|1" "$rc|$(grep -c 'GitHub API unreachable' <<<"$report")" "an unreachable API is reported, not fatal"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$UPDATE_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
