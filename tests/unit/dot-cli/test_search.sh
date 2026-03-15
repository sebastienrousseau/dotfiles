#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091
# Unit tests for the `dot search` command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

# ── dot search doctor ────────────────────────────────────────────

test_start "search_finds_doctor"
search_output=$(bash "$DOT_CLI" search doctor 2>&1)
if echo "$search_output" | grep -qi "doctor"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot search doctor returns doctor command"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot search doctor should return doctor"
  printf '%b\n' "    Got: '$search_output'"
fi

# ── dot search (no args) ────────────────────────────────────────

test_start "search_no_args_shows_usage"
search_no_args=$(bash "$DOT_CLI" search 2>&1)
exit_code=$?
if [[ $exit_code -ne 0 ]] && echo "$search_no_args" | grep -qi "usage"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot search with no args shows usage"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot search with no args should show usage"
  printf '%b\n' "    Exit code: $exit_code, Output: '$search_no_args'"
fi

# ── dot search nonexistent ──────────────────────────────────────

test_start "search_nonexistent_no_match"
search_none=$(bash "$DOT_CLI" search nonexistentxyz123 2>&1)
if echo "$search_none" | grep -qi "No commands matching"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot search nonexistent shows no match"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot search nonexistent should show 'No commands matching'"
  printf '%b\n' "    Got: '$search_none'"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "dot search tests completed."
print_summary
