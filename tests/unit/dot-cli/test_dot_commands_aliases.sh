#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI aliases commands (extracted module)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

ALIASES_FILE="$REPO_ROOT/scripts/dot/commands/aliases.sh"

# Test: aliases.sh file exists
test_start "aliases_cmd_file_exists"
assert_file_exists "$ALIASES_FILE" "aliases.sh should exist"

# Test: aliases.sh is valid shell syntax
test_start "aliases_cmd_syntax_valid"
if bash -n "$ALIASES_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: aliases.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: aliases.sh has syntax errors"
fi

# Test: defines cmd_aliases
test_start "aliases_cmd_defines_aliases"
assert_file_contains "$ALIASES_FILE" "cmd_aliases" "defines cmd_aliases function"

# Test: defines cmd_alias_check
test_start "aliases_cmd_defines_alias_check"
assert_file_contains "$ALIASES_FILE" "cmd_alias_check" "defines cmd_alias_check function"

# Test: defines alias_manifest_path
test_start "aliases_cmd_defines_manifest_path"
assert_file_contains "$ALIASES_FILE" "alias_manifest_path" "defines alias_manifest_path function"

# Test: defines emit_alias_manifest
test_start "aliases_cmd_defines_emit_manifest"
assert_file_contains "$ALIASES_FILE" "emit_alias_manifest" "defines emit_alias_manifest function"

# Test: has strict mode
test_start "aliases_cmd_strict_mode"
assert_file_contains "$ALIASES_FILE" "set -euo pipefail" "should use strict mode"

# Test: handles all subcommands
test_start "aliases_cmd_subcommands"
assert_file_contains "$ALIASES_FILE" "list)" "should handle list subcommand"
assert_file_contains "$ALIASES_FILE" "search)" "should handle search subcommand"
assert_file_contains "$ALIASES_FILE" "why)" "should handle why subcommand"
assert_file_contains "$ALIASES_FILE" "stats)" "should handle stats subcommand"
assert_file_contains "$ALIASES_FILE" "tiers)" "should handle tiers subcommand"

echo ""
echo "Aliases commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
