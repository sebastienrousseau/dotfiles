#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI agent commands (extracted module)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

AGENT_FILE="$REPO_ROOT/scripts/dot/commands/agent.sh"

# Test: agent.sh file exists
test_start "agent_cmd_file_exists"
assert_file_exists "$AGENT_FILE" "agent.sh should exist"

# Test: agent.sh is valid shell syntax
test_start "agent_cmd_syntax_valid"
if bash -n "$AGENT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: agent.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: agent.sh has syntax errors"
fi

# Test: defines cmd_mode
test_start "agent_cmd_defines_mode"
assert_file_contains "$AGENT_FILE" "cmd_mode" "defines cmd_mode function"

# Test: defines agent helper functions
test_start "agent_cmd_defines_helpers"
assert_file_contains "$AGENT_FILE" "_agent_profiles_file" "defines _agent_profiles_file"
assert_file_contains "$AGENT_FILE" "_agent_current_profile" "defines _agent_current_profile"
assert_file_contains "$AGENT_FILE" "_agent_apply_profile_env" "defines _agent_apply_profile_env"

# Test: has strict mode
test_start "agent_cmd_strict_mode"
assert_file_contains "$AGENT_FILE" "set -euo pipefail" "should use strict mode"

# Test: handles all mode subcommands
test_start "agent_cmd_mode_subcommands"
assert_file_contains "$AGENT_FILE" "list)" "should handle list subcommand"
assert_file_contains "$AGENT_FILE" "current)" "should handle current subcommand"
assert_file_contains "$AGENT_FILE" "show)" "should handle show subcommand"
assert_file_contains "$AGENT_FILE" "set)" "should handle set subcommand"
assert_file_contains "$AGENT_FILE" "run)" "should handle run subcommand"
assert_file_contains "$AGENT_FILE" "doctor)" "should handle doctor subcommand"
assert_file_contains "$AGENT_FILE" "card)" "should handle card subcommand"
assert_file_contains "$AGENT_FILE" "checkpoint)" "should handle checkpoint subcommand"
assert_file_contains "$AGENT_FILE" "conformance)" "should handle conformance subcommand"

# Test: checkpoint sub-subcommands
test_start "agent_cmd_checkpoint_subcommands"
assert_file_contains "$AGENT_FILE" "save)" "should handle checkpoint save"
assert_file_contains "$AGENT_FILE" "replay)" "should handle checkpoint replay"

echo ""
echo "Agent commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
