#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

test_start "dot_cli_has_verify"
assert_file_contains "$DOT_CLI" "verify)" "dot CLI should handle verify command"

test_start "dot_cli_has_scorecard"
assert_file_contains "$DOT_CLI" "scorecard)" "dot CLI should handle scorecard command"

test_start "dot_cli_has_snapshot"
assert_file_contains "$DOT_CLI" "snapshot)" "dot CLI should handle snapshot command"

test_start "dot_help_shows_verify"
output=$("$DOT_CLI" help)
if echo "$output" | grep -q "verify"; then
  ((TESTS_PASSED++)) || true
  printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: verify in help"
else
  ((TESTS_FAILED++)) || true
  printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: verify NOT in help"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
