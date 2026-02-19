#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Stable OS detection coverage tests (environment-compatible)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

OS_LIB="$REPO_ROOT/install/lib/os_detection.sh"

test_start "os_lib_exists"
assert_file_exists "$OS_LIB" "os_detection.sh should exist"

test_start "os_lib_syntax"
if bash -n "$OS_LIB" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST"
fi

# shellcheck source=/dev/null
source "$OS_LIB"

test_start "os_functions_exist"
if declare -F detect_os >/dev/null && declare -F is_macos >/dev/null && declare -F is_linux >/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: required functions are defined"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: required functions missing"
fi

test_start "detect_os_sets_variables"
detect_os
if [[ -n "${OS:-}" && -n "${ARCH:-}" && -n "${target_os:-}" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: OS/ARCH/target_os are set"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: detect_os did not set expected variables"
fi

test_start "target_os_is_known"
if [[ "$target_os" =~ ^(macos|wsl2|debian|fedora|arch|linux|unknown)$ ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: target_os=$target_os"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: unexpected target_os=$target_os"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
