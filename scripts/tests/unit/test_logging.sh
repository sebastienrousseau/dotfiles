#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for install/lib/logging.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

LOGGING_FILE="$REPO_ROOT/install/lib/logging.sh"

echo "Testing logging library..."

# Test: logging.sh exists
test_start "logging_file_exists"
assert_file_exists "$LOGGING_FILE" "logging.sh should exist"

# Test: logging.sh has valid syntax
test_start "logging_syntax"
assert_exit_code 0 "bash -n '$LOGGING_FILE'"

# Test: logging.sh has shebang
test_start "logging_shebang"
assert_file_contains "$LOGGING_FILE" "#!/usr/bin/env bash" "should have bash shebang"

# Test: logging.sh has double-source guard
test_start "logging_guard"
assert_file_contains "$LOGGING_FILE" "_DOTFILES_LOGGING_LOADED" "should have double-source guard"

# Test: log_info outputs to stdout with INFO prefix
test_start "log_info_output"
output=$(bash -c 'source "'"$LOGGING_FILE"'"; log_info "test message"' 2>&1)
if [[ "$output" == *"[INFO]"* && "$output" == *"test message"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: log_info shows INFO prefix"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: log_info should show INFO prefix"
  echo -e "    Output: $output"
fi

# Test: log_warn outputs with WARN prefix to stderr
test_start "log_warn_output"
output=$(bash -c 'source "'"$LOGGING_FILE"'"; log_warn "warn msg"' 2>&1)
if [[ "$output" == *"[WARN]"* && "$output" == *"warn msg"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: log_warn shows WARN prefix"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: log_warn should show WARN prefix"
  echo -e "    Output: $output"
fi

# Test: log_error outputs with ERROR prefix to stderr
test_start "log_error_output"
output=$(bash -c 'source "'"$LOGGING_FILE"'"; log_error "err msg"' 2>&1)
if [[ "$output" == *"[ERROR]"* && "$output" == *"err msg"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: log_error shows ERROR prefix"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: log_error should show ERROR prefix"
  echo -e "    Output: $output"
fi

# Test: die exits with code 1
test_start "die_exit_code"
assert_exit_code 1 "bash -c 'source \"$LOGGING_FILE\"; die \"fatal\"'"

# Test: die shows ERROR prefix
test_start "die_error_output"
output=$(bash -c 'source "'"$LOGGING_FILE"'"; die "fatal error"' 2>&1) || true
if [[ "$output" == *"[ERROR]"* && "$output" == *"fatal error"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: die shows ERROR prefix"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: die should show ERROR prefix"
  echo -e "    Output: $output"
fi

# Test: double-sourcing is idempotent
test_start "logging_idempotent"
output=$(bash -c '
  source "'"$LOGGING_FILE"'"
  source "'"$LOGGING_FILE"'"
  log_info "still works"
' 2>&1)
if [[ "$output" == *"still works"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: double-sourcing is safe"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: double-sourcing should be safe"
fi

print_summary
