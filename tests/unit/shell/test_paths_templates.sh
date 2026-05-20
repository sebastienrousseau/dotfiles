#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for PATH construction (00-core-paths.sh.tmpl)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

CORE_PATHS="$REPO_ROOT/dot_config/shell/00-core-paths.sh.tmpl"

# Test: core paths file exists
test_start "core_paths_exists"
assert_file_exists "$CORE_PATHS" "00-core-paths.sh.tmpl should exist"

# Test: sets PATH variable
test_start "core_paths_sets_path"
if grep -qE 'PATH=|path_prepend|export PATH' "$CORE_PATHS" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: sets PATH variable"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should set PATH variable"
fi

# Test: no hardcoded user paths
test_start "core_paths_no_hardcoded"
if grep -qE '"/home/[^$\{]|/Users/[^$\{]' "$CORE_PATHS" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: deduplication logic present
test_start "core_paths_has_dedup"
if grep -q '_seen_paths\|!seen' "$CORE_PATHS" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has dedup logic"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have dedup logic"
fi

echo ""
echo "Paths templates tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
