#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for tools scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

TOOLS_DIR="$REPO_ROOT/scripts/tools"

# Test: tools directory exists
test_start "tools_dir_exists"
assert_dir_exists "$TOOLS_DIR" "tools directory should exist"

# Test: log-rotate.sh exists and valid
test_start "tools_log_rotate_exists"
if [[ -f "$TOOLS_DIR/log-rotate.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: log-rotate.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: log-rotate.sh should exist"
fi

test_start "tools_log_rotate_syntax"
if [[ -f "$TOOLS_DIR/log-rotate.sh" ]] && bash -n "$TOOLS_DIR/log-rotate.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: log-rotate.sh valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: log-rotate.sh syntax errors"
fi

# Test: emoji-picker.sh exists
test_start "tools_emoji_picker_exists"
if [[ -f "$TOOLS_DIR/emoji-picker.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: emoji-picker.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: emoji-picker.sh should exist"
fi

# Test: all tools scripts have valid syntax
test_start "tools_all_valid_syntax"
invalid=0
for script in "$TOOLS_DIR"/*.sh; do
  if [[ -f "$script" ]] && ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
    echo "    Invalid: $(basename "$script")"
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all tools scripts valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid scripts have errors"
fi

# Test: no dangerous commands without guards
test_start "tools_no_dangerous_rm"
if grep -rqE 'rm -rf /[^$]' "$TOOLS_DIR"/*.sh 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has dangerous rm commands"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous rm commands"
fi

echo ""
echo "Tools scripts tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
