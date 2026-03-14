#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034,SC2317
# Behavioral tests for the lazy-loading stub pattern.
# Tests that stub wrappers defer real initialisation to first invocation,
# that they clean up themselves after loading, and that the loaded tool
# receives the original arguments correctly.
#
# The lazy loader pattern used in this repo (lazy_loaders.sh) looks like:
#   lazy_<tool>() {
#     unset -f <tool> lazy_<tool>
#     # ... real init ...
#     "$@"
#   }
#   alias <tool>="lazy_<tool> <tool>"
#
# We test a self-contained bash implementation of this contract.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/misc/lazy_loaders.sh"
if [[ ! -f "$FUNC_FILE" ]]; then
  echo "SKIP: lazy_loaders.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

mock_init

# ── Shared state for mock loader tracking ────────────────────────────────────
LOADER_CALLED=0
LOADER_ARGS=()

# ──────────────────────────────────────────────────────────────────────────────
# Reference implementation of the lazy-load pattern (bash, no alias needed)
# ──────────────────────────────────────────────────────────────────────────────
_setup_lazy_loader() {
  LOADER_CALLED=0
  LOADER_ARGS=()

  # The stub wraps "mytool" and defers real init.
  lazy_mytool() {
    unset -f mytool lazy_mytool 2>/dev/null || true
    LOADER_CALLED=1
    # In the real pattern, real init (e.g. eval "$(tool init)") happens here.
    # We simulate it by defining the "real" mytool:
    mytool() {
      LOADER_ARGS=("$@")
      echo "real_mytool: $*"
    }
    mytool "$@"
  }
  mytool() { lazy_mytool mytool "$@"; }
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. Loader function is NOT called before first use
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_loader_not_called_before_use"
_setup_lazy_loader
assert_equals "0" "$LOADER_CALLED" "loader should not run until first invocation"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Loader IS called on first invocation of the stub
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_loader_called_on_first_use"
_setup_lazy_loader
mytool arg1 >/dev/null 2>&1 || true
assert_equals "1" "$LOADER_CALLED" "loader should run exactly once on first invocation"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Arguments are forwarded to the real command
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_args_forwarded"
_setup_lazy_loader
mytool hello world >/dev/null 2>&1 || true
assert_equals "hello world" "${LOADER_ARGS[*]}" "arguments should be forwarded to the real command"

# ──────────────────────────────────────────────────────────────────────────────
# 4. After first use, the stub function is replaced (unset)
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_stub_replaced_after_first_use"
_setup_lazy_loader
mytool once >/dev/null 2>&1 || true
# 'lazy_mytool' should have been unset by the loader
if declare -f lazy_mytool >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lazy_mytool stub should be unset after first use"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lazy_mytool stub is unset after first use"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. After first use, the real function is available for direct calls
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_real_function_available_after_first_use"
_setup_lazy_loader
mytool >/dev/null 2>&1 || true
# The real mytool should now be defined and callable directly
if declare -f mytool >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: real mytool function is available after first use"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: real mytool function should be defined after loader runs"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Subsequent calls do NOT invoke the loader again
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_loader_not_called_again"
_setup_lazy_loader
mytool first >/dev/null 2>&1 || true
# Reset counter to detect any re-invocation of loader
LOADER_CALLED=0
mytool second >/dev/null 2>&1 || true
assert_equals "0" "$LOADER_CALLED" "loader should NOT be called again on second invocation"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Output of real command is returned to caller
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_output_returned"
_setup_lazy_loader
output=$(mytool some_input 2>&1)
assert_contains "real_mytool" "$output" "output from real command should be visible to caller"

# ──────────────────────────────────────────────────────────────────────────────
# 8. Guard: lazy loader is skipped if tool init file is absent
#    (tests the 'if [[ -s "$HOME/.nvm/nvm.sh" ]]' guard style)
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_load_guarded_when_init_absent"
# Simulate the guard check: only define lazy loader if init file exists.
local_init_file="/no/such/init_file_$$"
if [[ -s "$local_init_file" ]]; then
  lazy_guarded() { :; }
fi
if declare -f lazy_guarded >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lazy_guarded should NOT be defined when init file is absent"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lazy loader not defined when init file is absent"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 9. Verify lazy_loaders.sh syntax is valid
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_loaders_valid_syntax"
if bash -n "$FUNC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lazy_loaders.sh has valid bash syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lazy_loaders.sh has syntax errors"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 10. rbenv lazy loader wraps ruby/gem/bundle (structure check in source file)
# ──────────────────────────────────────────────────────────────────────────────
test_start "lazy_loaders_defines_rbenv_pattern"
if grep -q "lazy_rbenv" "$FUNC_FILE"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lazy_loaders.sh defines rbenv lazy-load pattern"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lazy_loaders.sh should define rbenv lazy-load pattern"
fi

mock_cleanup

echo ""
echo "lazy load behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
