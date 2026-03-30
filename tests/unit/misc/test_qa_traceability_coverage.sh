#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

TRACE_SCRIPT="$REPO_ROOT/scripts/qa/traceability-coverage.sh"
TRACE_DOC="$REPO_ROOT/docs/operations/TRACEABILITY.md"

test_start "traceability_coverage_script_exists"
assert_file_exists "$TRACE_SCRIPT" "traceability coverage script should exist"

test_start "traceability_coverage_script_syntax"
assert_exit_code 0 "bash -n '$TRACE_SCRIPT'"

test_start "traceability_doc_exists"
assert_file_exists "$TRACE_DOC" "traceability document should exist"

test_start "traceability_doc_covers_core_behaviors"
assert_file_contains "$TRACE_DOC" "BT-01" "traceability doc should include BT-01"
assert_file_contains "$TRACE_DOC" "BT-05" "traceability doc should include BT-05"
assert_file_contains "$TRACE_DOC" "BT-10" "traceability doc should include BT-10"

test_start "traceability_contract_passes"
assert_exit_code 0 "bash '$TRACE_SCRIPT'"

test_start "traceability_contract_reports_100_percent_floor"
assert_file_contains "$TRACE_SCRIPT" 'MIN_TRACEABILITY_COVERAGE="${MIN_TRACEABILITY_COVERAGE:-100}"' "traceability coverage contract should default to a 100% floor"
assert_file_contains "$TRACE_SCRIPT" 'Traceability coverage:' "traceability coverage contract should report a percentage"
