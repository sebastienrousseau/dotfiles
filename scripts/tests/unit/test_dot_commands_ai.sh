#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot AI bridge command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

AI_SCRIPT="$REPO_ROOT/scripts/dot/commands/ai.sh"

test_start "ai_bridge_exists"
assert_file_exists "$AI_SCRIPT" "ai.sh should exist"

test_start "ai_bridge_syntax"
assert_exit_code 0 "bash -n '$AI_SCRIPT'"

test_start "ai_bridge_defines_run_ai"
assert_file_contains "$AI_SCRIPT" "run_ai_with_context()" "should define run_ai_with_context"

test_start "ai_bridge_metadata_injection"
assert_file_contains "$AI_SCRIPT" "System Metadata" "should inject system metadata"

test_start "ai_bridge_pattern_handling"
assert_file_contains "$AI_SCRIPT" "--pattern" "should handle pattern flag"

test_start "ai_bridge_help_shows_patterns"
output=$(bash "$AI_SCRIPT" --help 2>&1 || true)
if echo "$output" | grep -q "Available Patterns"; then
  ((TESTS_PASSED++)) || true
  printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: help shows patterns"
else
  ((TESTS_FAILED++)) || true
  printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: help missing patterns"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
