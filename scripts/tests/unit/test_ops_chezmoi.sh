#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for chezmoi operations scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

OPS_DIR="$REPO_ROOT/scripts/ops"

# Test: chezmoi-apply.sh exists
test_start "chezmoi_apply_exists"
assert_file_exists "$OPS_DIR/chezmoi-apply.sh" "chezmoi-apply.sh should exist"

# Test: chezmoi-apply.sh valid syntax
test_start "chezmoi_apply_syntax"
if bash -n "$OPS_DIR/chezmoi-apply.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: chezmoi-diff.sh exists
test_start "chezmoi_diff_exists"
assert_file_exists "$OPS_DIR/chezmoi-diff.sh" "chezmoi-diff.sh should exist"

# Test: chezmoi-diff.sh valid syntax
test_start "chezmoi_diff_syntax"
if bash -n "$OPS_DIR/chezmoi-diff.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: chezmoi-update.sh exists
test_start "chezmoi_update_exists"
assert_file_exists "$OPS_DIR/chezmoi-update.sh" "chezmoi-update.sh should exist"

# Test: chezmoi-update.sh valid syntax
test_start "chezmoi_update_syntax"
if bash -n "$OPS_DIR/chezmoi-update.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: chezmoi-remove.sh exists
test_start "chezmoi_remove_exists"
assert_file_exists "$OPS_DIR/chezmoi-remove.sh" "chezmoi-remove.sh should exist"

# Test: all use chezmoi command
test_start "chezmoi_ops_use_chezmoi"
found=0
for script in "$OPS_DIR"/chezmoi-*.sh; do
  if [[ -f "$script" ]] && grep -q 'chezmoi' "$script" 2>/dev/null; then
    ((found++))
  fi
done
if [[ $found -ge 3 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: ops scripts use chezmoi command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: ops scripts should use chezmoi"
fi

echo ""
echo "Chezmoi operations tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
