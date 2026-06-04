#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/security-score.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "security_score_exists"
assert_file_exists "$TEST_SCRIPT" "security-score.sh should exist"

test_start "security_score_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "security_score_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "security_score_flag_aliases"
assert_file_contains "$TEST_SCRIPT" "--verbose | -v" "security-score supports -v"
assert_file_contains "$TEST_SCRIPT" "--quiet | -q" "security-score supports -q"
assert_file_contains "$TEST_SCRIPT" "--json | -j" "security-score supports -j"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
