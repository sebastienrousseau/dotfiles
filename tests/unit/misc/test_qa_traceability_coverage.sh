#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

TRACE_SCRIPT="$REPO_ROOT/scripts/qa/traceability-coverage.sh"
TRACE_DOC="$REPO_ROOT/docs/operations/TRACEABILITY.md"

test_start "traceability_coverage_script_exists"
assert_file_exists "$TRACE_SCRIPT" "traceability coverage script should exist"

test_start "traceability_doc_exists"
assert_file_exists "$TRACE_DOC" "traceability document should exist"

test_start "traceability_doc_covers_core_behaviors"
assert_file_contains "$TRACE_DOC" "BT-01" "traceability doc should include BT-01"
assert_file_contains "$TRACE_DOC" "BT-05" "traceability doc should include BT-05"
assert_file_contains "$TRACE_DOC" "BT-10" "traceability doc should include BT-10"

test_start "traceability_contract_passes"
assert_exit_code 0 "bash '$TRACE_SCRIPT'"

test_start "traceability_contract_reports_100_percent_floor"
trace_out="$(bash "$TRACE_SCRIPT" 2>&1)"
trace_counts="$(printf '%s\n' "$trace_out" | sed -n 's|^Traceability coverage: \([0-9]*\)/\([0-9]*\) (100\.00%)$|\1 \2|p')"
assert_equals "true" "$([[ -n "$trace_counts" && "${trace_counts% *}" == "${trace_counts#* }" ]] && echo true || echo false)" \
  "every check is covered: ${trace_counts:-no report line}"
assert_contains "Threshold: 100%" "$trace_out" "the floor defaults to 100%"

# The traceability doc without the files it points to: every missing target
# is named and the 100% floor fails the run.
test_start "traceability_names_missing_targets_and_fails_the_floor"
TRACE_WORK="$(mktemp -d -t dot-trace-cov.XXXXXX)"
trap 'rm -rf "$TRACE_WORK"' EXIT
mkdir -p "$TRACE_WORK/scripts/qa" "$TRACE_WORK/docs/operations"
cp "$TRACE_SCRIPT" "$TRACE_WORK/scripts/qa/traceability-coverage.sh"
cp "$TRACE_DOC" "$TRACE_WORK/docs/operations/TRACEABILITY.md"
gap_rc=0
gap_out="$(bash "$TRACE_WORK/scripts/qa/traceability-coverage.sh" 2>&1)" || gap_rc=$?
assert_not_equals "0" "$gap_rc" "missing targets fail the run"
assert_contains "Missing traceability target: BT-01" "$gap_out" "and each is named"
