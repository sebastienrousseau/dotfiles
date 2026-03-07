#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Unit tests for dot/lib/bento.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

BENTO_FILE="$REPO_ROOT/scripts/dot/lib/bento.sh"

# Test: bento.sh file exists
test_start "bento_file_exists"
assert_file_exists "$BENTO_FILE" "bento.sh should exist"

# Test: bento.sh is valid shell syntax
test_start "bento_syntax_valid"
if bash -n "$BENTO_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: bento.sh has valid syntax\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: bento.sh has syntax errors\n"
fi

# Test: defines bento function
test_start "bento_defines_function"
if grep -q "_dotfiles_bento_render" "$BENTO_FILE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: defines bento render function\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: should define _dotfiles_bento_render\n"
fi

# Test: uses 24-bit escape codes (Liquid Glass)
test_start "bento_uses_24bit_colors"
if grep -q "38;2;" "$BENTO_FILE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: uses 24-bit escape codes\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: should use 24-bit escape codes\n"
fi

# Test: contains branding
test_start "bento_branding"
if grep -q "D O T F I L E S" "$BENTO_FILE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: contains branding\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: should contain branding\n"
fi

# Test: execution output
test_start "bento_execution"
output=$(bash "$BENTO_FILE" 2>/dev/null)
if [[ $output == *"D O T F I L E S"* ]]; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: renders output correctly\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: output missing branding\n"
fi

echo ""
echo "Bento library tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
