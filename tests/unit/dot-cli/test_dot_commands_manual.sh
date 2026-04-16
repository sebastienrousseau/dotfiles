#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/manual.sh"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "manual.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "supports_all_formats"
for fmt in html pdf epub text markdown; do
  assert_file_contains "$SCRIPT_FILE" "$fmt" "must support $fmt format"
done

test_start "uses_system_open_on_darwin"
assert_file_contains "$SCRIPT_FILE" "/usr/bin/open" "must use /usr/bin/open explicitly to avoid recursion"

test_start "registered_in_dot_cli"
DOT_BIN="$REPO_ROOT/dot_local/bin/executable_dot"
assert_file_contains "$DOT_BIN" "manual|manual" "dot CLI must route 'manual' command"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
