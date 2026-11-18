#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for install/lib/chezmoi.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

CHEZMOI_LIB="$REPO_ROOT/install/lib/chezmoi.sh"

if [[ ! -f "$CHEZMOI_LIB" ]]; then
  echo "SKIP: chezmoi.sh not found at $CHEZMOI_LIB"
  echo "RESULTS:0:0:0"
  exit 0
fi

# Test: chezmoi.sh file exists
test_start "chezmoi_lib_exists"
assert_file_exists "$CHEZMOI_LIB" "chezmoi.sh should exist"

# Test: chezmoi.sh is valid shell syntax
test_start "chezmoi_lib_syntax"
if bash -n "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid shell syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: defines install function
test_start "chezmoi_lib_install_func"
if grep -qE 'install_chezmoi|chezmoi_install' "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines install function"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define install function"
fi

# Test: uses official install method
test_start "chezmoi_lib_official_install"
if grep -qE 'get.chezmoi.io|chezmoi/chezmoi' "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses official install method"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use official install"
fi

# Test: checks for existing installation
test_start "chezmoi_lib_checks_existing"
if grep -qE 'command -v chezmoi|which chezmoi' "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: checks for existing installation"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should check existing install"
fi

# Runs install_chezmoi_binary with the download mocked: the "installer"
# records the arguments it was given. Prints them.
run_binary_install_args() {
  local work bin_dir
  work="$(mktemp -d)"
  bin_dir="$work/bin"
  (
    CHEZMOI_VERSION="$1"
    [[ -n "$CHEZMOI_VERSION" ]] || unset CHEZMOI_VERSION
    source "$CHEZMOI_LIB"
    download_verified_script() {
      printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"%s/args"\n' "$work" >"$2"
    }
    install_chezmoi_binary "$bin_dir" >/dev/null 2>&1
  ) || true
  tr '\n' ' ' <"$work/args" 2>/dev/null
  rm -rf "$work"
}

# get.chezmoi.io must be told the version (-t) and the directory (-b) as
# options; a leading `--` made it ignore both and float to the latest tag.
test_start "chezmoi_lib_binary_install_pins_tag"
args="$(run_binary_install_args "")"
assert_contains "-t v2.74.1 " "$args" "installer is pinned to the repo's chezmoi version"
assert_contains "-b " "$args" "installer receives -b as an option"
assert_equals "-b" "${args%% *}" "options come first; no '--' that ends option parsing"

test_start "chezmoi_lib_binary_install_honours_chezmoi_version"
args="$(run_binary_install_args "2.80.0")"
assert_contains "-t v2.80.0 " "$args" "CHEZMOI_VERSION overrides the pinned tag"

# Test: shellcheck compliance
echo ""
echo "Chezmoi library tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
