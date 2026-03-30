#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

audit_script="$REPO_ROOT/scripts/qa/reliability-audit.sh"
examples_script="$REPO_ROOT/scripts/qa/validate-examples.sh"
docs_coverage_script="$REPO_ROOT/scripts/qa/docs-coverage.sh"
traceability_script="$REPO_ROOT/scripts/qa/traceability-coverage.sh"
platform_example="$REPO_ROOT/examples/example-platform-contract.sh"
wsl_contract_script="$REPO_ROOT/scripts/qa/wsl-contract.sh"
reliability_workflow="$REPO_ROOT/.github/workflows/reliability-gate.yml"

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

test_start "qa_docs_coverage_exists"
assert_file_exists "$docs_coverage_script" "docs-coverage.sh exists"

test_start "qa_docs_coverage_syntax"
assert_exit_code 0 "bash -n '$docs_coverage_script'"

test_start "qa_traceability_coverage_exists"
assert_file_exists "$traceability_script" "traceability-coverage.sh exists"

test_start "qa_traceability_coverage_syntax"
assert_exit_code 0 "bash -n '$traceability_script'"

test_start "qa_validate_examples_syntax"
assert_exit_code 0 "bash -n '$examples_script'"

test_start "qa_validate_examples_contract"
assert_file_contains "$examples_script" "examples" "examples directory referenced"
assert_file_contains "$examples_script" "Running example:" "example execution output present"

test_start "qa_reliability_quick_mode_behavior"
assert_file_contains "$audit_script" "if [ \"\$mode\" = \"full\" ]; then" "full mode branch present"
assert_file_contains "$audit_script" "run_step \"Integration suite\" integration_tests" "integration step present"
assert_file_contains "$audit_script" "if [ \"\$run_integration\" -eq 1 ]; then" "integration branch guard present"
assert_file_contains "$audit_script" "run_step \"Docs coverage\" docs_coverage_gate" "docs coverage step present"
assert_file_contains "$audit_script" "run_step \"Traceability coverage\" traceability_gate" "traceability coverage step present"

test_start "qa_examples_include_platform_contract"
assert_file_exists "$platform_example" "platform contract example exists"
assert_file_contains "$platform_example" "dot_platform_id" "platform example prints platform id"
assert_file_contains "$platform_example" "dot_host_os" "platform example prints host os"

test_start "qa_wsl_contract_exists"
assert_file_exists "$wsl_contract_script" "wsl contract script exists"
assert_file_contains "$wsl_contract_script" "test_os_detection_comprehensive.sh" "wsl contract runs os detection coverage"
assert_file_contains "$wsl_contract_script" "test_platform_detection_behavior.sh" "wsl contract runs platform behavior coverage"

test_start "qa_reliability_workflow_contract_jobs"
assert_file_contains "$reliability_workflow" "name: Examples Contract" "reliability workflow includes examples contract"
assert_file_contains "$reliability_workflow" "name: WSL Contract" "reliability workflow includes wsl contract"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
