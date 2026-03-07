#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/chaos.sh"

test_start "chaos_exists"
assert_file_exists "$TEST_SCRIPT" "chaos.sh should exist"

test_start "chaos_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "chaos_requires_force"
output=$(bash "$TEST_SCRIPT" 2>&1 || true)
if echo "$output" | grep -q "To run, execute"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: requires --force flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: failed to require --force flag"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
