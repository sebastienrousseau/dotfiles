#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/ai-setup.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "ai_setup_exists"
assert_file_exists "$TEST_SCRIPT" "ai-setup.sh should exist"

test_start "ai_setup_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "ai_setup_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "ai_setup_includes_copilot"
assert_file_contains "$TEST_SCRIPT" "setup_tool \"Copilot CLI\" \"copilot\" copilot --version" "should setup Copilot CLI"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
