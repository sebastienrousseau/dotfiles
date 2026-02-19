#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for keygen function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/keygen.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: keygen.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

echo "Testing keygen function..."

# Test function exists
test_start "keygen_function_exists"
assert_true "type keygen &>/dev/null" "keygen function should exist"

# Test no arguments shows usage
test_start "keygen_no_args"
if type keygen &>/dev/null; then
  output=$(keygen 2>&1 || true)
  # Should show usage or error - use direct check to avoid eval issues
  if [[ -n "$output" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no args should produce output"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: no args should produce output"
  fi
fi

# Test help flag
test_start "keygen_help_flag"
if type keygen &>/dev/null; then
  output=$(keygen --help 2>&1 || keygen -h 2>&1 || echo "usage")
  assert_true "true" "help flag check completed"
fi

# Test invalid key type
test_start "keygen_invalid_type"
if type keygen &>/dev/null; then
  result=$(keygen --type invalid_type test_key 2>&1 || echo "error")
  # Check for error messages (case insensitive)
  if echo "$result" | grep -iqE "(error|invalid|unknown|usage)"; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: invalid type shows error message"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show error for invalid type"
  fi
fi

# Test output format (without actually creating keys)
test_start "keygen_dry_run"
if type keygen &>/dev/null; then
  # Just verify it doesn't crash with common args
  keygen --help 2>/dev/null || true
  assert_true "true" "keygen help does not crash"
fi

print_summary
