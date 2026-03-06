#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/smoke-test.sh"

test_start "smoke_test_exists"
assert_file_exists "$TEST_SCRIPT" "smoke-test.sh should exist"

test_start "smoke_test_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "smoke_test_defines_check_cmd"
assert_file_contains "$TEST_SCRIPT" "check_cmd()" "should define check_cmd"

test_start "smoke_test_defines_verify_cmd"
assert_file_contains "$TEST_SCRIPT" "verify_cmd()" "should define verify_cmd"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
