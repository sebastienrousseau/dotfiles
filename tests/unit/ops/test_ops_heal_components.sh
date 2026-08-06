#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

heal_chezmoi="$REPO_ROOT/scripts/ops/heal-chezmoi.sh"
heal_system="$REPO_ROOT/scripts/ops/heal-system.sh"
heal_tools="$REPO_ROOT/scripts/ops/heal-tools.sh"

test_start "heal_chezmoi_exists"
assert_file_exists "$heal_chezmoi" "heal-chezmoi.sh exists"

test_start "heal_chezmoi_syntax"
assert_exit_code 0 "bash -n '$heal_chezmoi'"

test_start "heal_chezmoi_functions"
assert_file_contains "$heal_chezmoi" "create_pre_heal_backup()" "create_pre_heal_backup present"
assert_file_contains "$heal_chezmoi" "heal_chezmoi_drift()" "heal_chezmoi_drift present"

test_start "heal_system_exists"
assert_file_exists "$heal_system" "heal-system.sh exists"

test_start "heal_system_syntax"
assert_exit_code 0 "bash -n '$heal_system'"

test_start "heal_system_functions"
assert_file_contains "$heal_system" "heal_broken_symlinks()" "heal_broken_symlinks present"
assert_file_contains "$heal_system" "heal_missing_critical_files()" "heal_missing_critical_files present"
assert_file_contains "$heal_system" "heal_missing_xdg_dirs()" "heal_missing_xdg_dirs present"

test_start "heal_tools_exists"
assert_file_exists "$heal_tools" "heal-tools.sh exists"

test_start "heal_tools_syntax"
assert_exit_code 0 "bash -n '$heal_tools'"

test_start "heal_tools_functions"
assert_file_contains "$heal_tools" "detect_pkg_manager()" "detect_pkg_manager present"
assert_file_contains "$heal_tools" "install_package()" "install_package present"
assert_file_contains "$heal_tools" "_mise_tool_specs()" "pinned mise mapping present"

test_start "heal_tools_has_no_direct_binary_downloads"
if rg -q 'github\.com/.*/releases/.*/(download|latest)' "$heal_tools"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: direct release download found"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "heal_tools_mise_specs_are_exact"
# shellcheck disable=SC1090
source "$heal_tools"
specs="$(for tool in nushell pueue wasmtime sops yazi zellij; do _mise_tool_specs "$tool"; done)"
if [[ "$(printf '%s\n' "$specs" | wc -l | tr -d ' ')" -eq 7 ]] &&
  ! grep -Ev '^[A-Za-z0-9:_/-]+@[0-9]+\.[0-9]+\.[0-9]+$' <<<"$specs" | grep -q .; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invalid specs"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
