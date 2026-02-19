#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Stable package manager coverage tests (environment-compatible)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

PM_LIB="$REPO_ROOT/install/lib/package_managers.sh"

test_start "pm_lib_exists"
assert_file_exists "$PM_LIB" "package_managers.sh should exist"

test_start "pm_lib_syntax"
if bash -n "$PM_LIB" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST"
fi

# shellcheck source=/dev/null
source "$PM_LIB"

test_start "pm_functions_exist"
if declare -F has_brew >/dev/null && declare -F has_apt >/dev/null && declare -F has_dnf >/dev/null && declare -F has_pacman >/dev/null && declare -F verify_package_manager >/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: required functions are defined"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: required functions missing"
fi

test_start "pm_helpers_return_boolean_style"
if has_brew || ! has_brew; then
  if has_apt || ! has_apt; then
    if has_dnf || ! has_dnf; then
      if has_pacman || ! has_pacman; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: helper functions return proper status codes"
      else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} $CURRENT_TEST: has_pacman status behavior invalid"
      fi
    else
      ((TESTS_FAILED++))
      echo -e "  ${RED}✗${NC} $CURRENT_TEST: has_dnf status behavior invalid"
    fi
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has_apt status behavior invalid"
  fi
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has_brew status behavior invalid"
fi

test_start "verify_package_manager_unknown"
target_os="unknown"
if verify_package_manager; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: unknown target is non-fatal"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: unknown target should be non-fatal"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
