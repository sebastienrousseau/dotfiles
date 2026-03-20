#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI fleet commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FLEET_FILE="$REPO_ROOT/scripts/dot/commands/fleet.sh"

# Test: fleet.sh file exists
test_start "fleet_cmd_file_exists"
assert_file_exists "$FLEET_FILE" "fleet.sh should exist"

# Test: fleet.sh is valid shell syntax
test_start "fleet_cmd_syntax_valid"
if bash -n "$FLEET_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: fleet.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: fleet.sh has syntax errors"
fi

# Test: defines fleet status command
test_start "fleet_cmd_defines_status"
assert_file_contains "$FLEET_FILE" "cmd_fleet_status" "defines fleet status command"

# Test: defines fleet drift command
test_start "fleet_cmd_defines_drift"
assert_file_contains "$FLEET_FILE" "cmd_fleet_drift" "defines fleet drift command"

# Test: defines fleet events command
test_start "fleet_cmd_defines_events"
assert_file_contains "$FLEET_FILE" "cmd_fleet_events" "defines fleet events command"

# Test: defines fleet namespace command
test_start "fleet_cmd_defines_namespace"
assert_file_contains "$FLEET_FILE" "cmd_fleet_namespace" "defines fleet namespace command"

# Test: has strict mode
test_start "fleet_cmd_strict_mode"
assert_file_contains "$FLEET_FILE" "set -euo pipefail" "should use strict mode"

# Test: emits structured events
test_start "fleet_cmd_emits_events"
assert_file_contains "$FLEET_FILE" "_fleet_emit_event" "should emit structured fleet events"

# Test: supports JSON output
test_start "fleet_cmd_json_support"
assert_file_contains "$FLEET_FILE" "json_mode" "should support JSON output mode"

# Test: no hardcoded paths
test_start "fleet_cmd_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$FLEET_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

echo ""
echo "Fleet commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
