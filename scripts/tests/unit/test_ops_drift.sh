#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for drift.sh - smart drift detection with auto-remediation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/drift.sh"

echo "Testing drift.sh..."

# Test: file exists
test_start "drift_exists"
assert_file_exists "$SCRIPT_FILE" "drift.sh should exist"

# Test: valid shell syntax
test_start "drift_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "drift_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "drift_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "drift_ui_lib"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui library"

# Test: defines analyze_drift function
test_start "drift_analyze_function"
assert_file_contains "$SCRIPT_FILE" "analyze_drift()" "should define analyze_drift function"

# Test: uses chezmoi status
test_start "drift_chezmoi_status"
assert_file_contains "$SCRIPT_FILE" "chezmoi status" "should use chezmoi status"

# Test: categorizes by severity
test_start "drift_severity_categories"
if grep -q "critical" "$SCRIPT_FILE" && grep -q "warning" "$SCRIPT_FILE" && grep -q "safe" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: categorizes by severity"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should categorize by severity"
fi

# Test: tracks file types
test_start "drift_file_types"
if grep -q "modified" "$SCRIPT_FILE" && grep -q "added" "$SCRIPT_FILE" && grep -q "deleted" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: tracks file types (modified/added/deleted)"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should track file types"
fi

# Test: detects security-sensitive files
test_start "drift_security_files"
if grep -q ".ssh" "$SCRIPT_FILE" && grep -q "secrets" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: detects security-sensitive files"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should detect security-sensitive files"
fi

# Test: uses XDG state home for logs
test_start "drift_xdg_state"
assert_file_contains "$SCRIPT_FILE" "XDG_STATE_HOME" "should use XDG state home for logs"

# Test: defines DRIFT_LOG
test_start "drift_log_file"
assert_file_contains "$SCRIPT_FILE" "DRIFT_LOG=" "should define drift log file"

# Test: exports drift statistics
test_start "drift_statistics"
if grep -q "DRIFT_MODIFIED" "$SCRIPT_FILE" && grep -q "DRIFT_TOTAL" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: exports drift statistics"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should export drift statistics"
fi

# Test: handles shell configuration files
test_start "drift_shell_config"
if grep -q ".zshrc" "$SCRIPT_FILE" || grep -q ".bashrc" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: handles shell configuration files"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle shell configuration files"
fi

# Test: handles editor configs
test_start "drift_editor_config"
assert_file_contains "$SCRIPT_FILE" "nvim" "should handle nvim config files"

# Test: uses ui_init
test_start "drift_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should initialize ui"

echo ""
echo "drift.sh tests completed."
print_summary
