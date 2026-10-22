#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Unit tests for the `dot help` command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

# ── dot help doctor ────────────────────────────────────────────

test_start "search_finds_doctor"
search_output=$(bash "$DOT_CLI" help doctor 2>&1)
if echo "$search_output" | grep -qi "doctor"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot help doctor returns doctor command"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot help doctor should return doctor"
  printf '%b\n' "    Got: '$search_output'"
fi

# ── dot help (no args) ────────────────────────────────────────

test_start "search_no_args_shows_usage"
search_no_args=$(bash "$DOT_CLI" help 2>&1)
exit_code=$?
# `dot search` became `dot help`: with no term it is the overview.
if [[ $exit_code -eq 0 ]] && echo "$search_no_args" | grep -q "dot help <term>"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot help with no args shows usage"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot help with no args should show usage"
  printf '%b\n' "    Exit code: $exit_code, Output: '$search_no_args'"
fi

# ── dot help nonexistent ──────────────────────────────────────

test_start "search_nonexistent_no_match"
search_none=$(bash "$DOT_CLI" help nonexistentxyz123 2>&1)
if echo "$search_none" | grep -qi "Unknown help topic"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot help nonexistent shows no match"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot help nonexistent should say 'Unknown help topic'"
  printf '%b\n' "    Got: '$search_none'"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "dot help tests completed."
print_summary
