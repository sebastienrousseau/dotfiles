#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/perf.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "perf_exists"
assert_file_exists "$TEST_SCRIPT" "perf.sh should exist"

test_start "perf_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "perf_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "perf_flag_aliases"
assert_file_contains "$TEST_SCRIPT" "--json | -j" "perf supports -j"
assert_file_contains "$TEST_SCRIPT" "--profile | -p" "perf supports -p"
assert_file_contains "$TEST_SCRIPT" "--runs | -r" "perf supports -r"
assert_file_contains "$TEST_SCRIPT" "--target | -t" "perf supports -t"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
