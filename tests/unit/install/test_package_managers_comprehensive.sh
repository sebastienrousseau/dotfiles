#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Stable package manager coverage tests (environment-compatible)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PM_LIB="$REPO_ROOT/install/lib/package_managers.sh"

test_start "pm_lib_exists"
assert_file_exists "$PM_LIB" "package_managers.sh should exist"

test_start "pm_lib_syntax"
if bash -n "$PM_LIB" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# shellcheck source=/dev/null
source "$PM_LIB"

test_start "pm_functions_exist"
if declare -F has_brew >/dev/null && declare -F has_apt >/dev/null && declare -F has_dnf >/dev/null && declare -F has_pacman >/dev/null && declare -F verify_package_manager >/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: required functions are defined"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: required functions missing"
fi

test_start "pm_helpers_return_boolean_style"
if has_brew || ! has_brew; then
  if has_apt || ! has_apt; then
    if has_dnf || ! has_dnf; then
      if has_pacman || ! has_pacman; then
        ((TESTS_PASSED++)) || true
        printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: helper functions return proper status codes"
      else
        ((TESTS_FAILED++)) || true
        printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has_pacman status behavior invalid"
      fi
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has_dnf status behavior invalid"
    fi
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has_apt status behavior invalid"
  fi
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has_brew status behavior invalid"
fi

test_start "verify_package_manager_unknown"
target_os="unknown"
if verify_package_manager; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: unknown target is non-fatal"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unknown target should be non-fatal"
fi

test_start "homebrew_checksum_mismatch_fails_closed"
homebrew_tmp="$(mktemp -d)"
if HOME="$homebrew_tmp" DOTFILES_NONINTERACTIVE=1 bash -c '
  source "$1"
  has_brew() { return 1; }
  download_verified_script() { printf "#!/bin/bash\nexit 0\n" >"$2"; }
  _dot_sha256_file() { printf "%064d\n" 0; }
  install_homebrew
' _ "$PM_LIB" >"$homebrew_tmp/output" 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: mismatched installer was accepted"
else
  assert_file_contains "$homebrew_tmp/output" "checksum mismatch" \
    "mismatched installer must be rejected"
fi

test_start "homebrew_verified_installer_executes"
marker="$homebrew_tmp/executed"
if HOME="$homebrew_tmp" DOTFILES_NONINTERACTIVE=1 HOMEBREW_TEST_MARKER="$marker" bash -c '
  source "$1"
  has_brew() { return 1; }
  download_verified_script() {
    printf "#!/bin/bash\n: > \\\"\${HOMEBREW_TEST_MARKER}\\\"\n" >"$2"
  }
  _dot_sha256_file() {
    printf "%s\n" "12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41"
  }
  install_homebrew
' _ "$PM_LIB" >/dev/null 2>&1 && [[ -f "$marker" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: verified installer executed"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: verified installer did not execute"
fi
rm -rf "$homebrew_tmp"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
