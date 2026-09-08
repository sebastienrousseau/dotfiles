#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the two documentation gates in scripts/qa:
# docs-coverage.sh and traceability-coverage.sh. Both are run against the
# repository as it stands (they are read-only reporters) and then re-run with
# an impossible threshold to drive the failure verdict.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOCS="$REPO_ROOT/scripts/qa/docs-coverage.sh"
TRACE="$REPO_ROOT/scripts/qa/traceability-coverage.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"

gate() {
  # stderr is replayed, not merged, so the child's xtrace still reaches the
  # coverage trace while its "Missing …" lines stay assertable.
  "$@" >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  assert_file_contains "$MERGED" "$1" "${2:-output contains $1}"
}

# ── docs-coverage ───────────────────────────────────────────────────────
test_start "docs_coverage_reports_a_ratio_and_its_threshold"
gate bash "$DOCS"
assert_equals 0 "$RC" "the repository meets its own docs threshold"
out_has "Docs coverage:" "ratio reported"
out_has "Threshold: 100%" "threshold reported"
out_has "PASS: public dot commands" "verdict"

test_start "docs_coverage_counts_every_checked_surface"
# commands from bin/dot + 9 AI providers + 40 utilities + the function groups.
total="$(sed -n 's/^Docs coverage: [0-9]*\/\([0-9]*\) .*/\1/p' "$OUTF")"
assert_true "[[ ${total:-0} -gt 100 ]]" "more than a hundred checks run"
covered="$(sed -n 's/^Docs coverage: \([0-9]*\)\/.*/\1/p' "$OUTF")"
assert_equals "$total" "$covered" "every documented surface is present"

test_start "docs_coverage_fails_an_unreachable_threshold"
gate env MIN_DOCS_COVERAGE=101 bash "$DOCS"
assert_equals 1 "$RC" "rc"
out_has "Threshold: 101%" "threshold echoed"
out_has "FAIL: docs coverage below MIN_DOCS_COVERAGE=101%" "verdict"

# ── traceability-coverage ───────────────────────────────────────────────
test_start "traceability_reports_a_ratio_and_its_threshold"
gate bash "$TRACE"
assert_equals 0 "$RC" "the repository meets its own traceability threshold"
out_has "Traceability coverage:" "ratio reported"
out_has "Threshold: 100%" "threshold reported"
out_has "PASS: core internal behaviors" "verdict"

test_start "traceability_checks_every_behaviour_row_and_command_module"
total="$(sed -n 's/^Traceability coverage: [0-9]*\/\([0-9]*\) .*/\1/p' "$OUTF")"
assert_true "[[ ${total:-0} -gt 50 ]]" "the matrix is non-trivial"
covered="$(sed -n 's/^Traceability coverage: \([0-9]*\)\/.*/\1/p' "$OUTF")"
assert_equals "$total" "$covered" "every referenced path exists"

test_start "traceability_fails_an_unreachable_threshold"
gate env MIN_TRACEABILITY_COVERAGE=101 bash "$TRACE"
assert_equals 1 "$RC" "rc"
out_has "Threshold: 101%" "threshold echoed"
out_has "FAIL: traceability coverage below MIN_TRACEABILITY_COVERAGE=101%" "verdict"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
