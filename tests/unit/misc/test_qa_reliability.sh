#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

audit_script="$REPO_ROOT/scripts/qa/reliability-audit.sh"
examples_script="$REPO_ROOT/scripts/qa/validate-examples.sh"

test_start "qa_reliability_audit_exists"
assert_file_exists "$audit_script" "reliability-audit.sh exists"

test_start "qa_reliability_audit_syntax"
assert_exit_code 0 "bash -n '$audit_script'"

test_start "qa_reliability_flags"
assert_file_contains "$audit_script" "--quick" "quick mode flag present"
assert_file_contains "$audit_script" "--unit-only" "unit mode flag present"
assert_file_contains "$audit_script" "--with-integration" "integration flag present"

test_start "qa_validate_examples_exists"
assert_file_exists "$examples_script" "validate-examples.sh exists"

test_start "qa_validate_examples_syntax"
assert_exit_code 0 "bash -n '$examples_script'"

test_start "qa_validate_examples_contract"
assert_file_contains "$examples_script" "examples" "examples directory referenced"
assert_file_contains "$examples_script" "Running example:" "example execution output present"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
