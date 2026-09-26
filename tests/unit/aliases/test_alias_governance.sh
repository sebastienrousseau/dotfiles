#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for alias governance checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

GOVERNANCE_SCRIPT="$REPO_ROOT/scripts/diagnostics/alias-governance.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
MANIFEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/aliases-manifest.sh"
CD_INIT_FILE="$REPO_ROOT/defaults/.chezmoitemplates/aliases/cd/cd-init.aliases.sh"

test_start "alias_governance_script_exists"
assert_file_exists "$GOVERNANCE_SCRIPT" "alias governance script should exist"

test_start "alias_manifest_script_exists"
assert_file_exists "$MANIFEST_SCRIPT" "alias manifest script should exist"

test_start "alias_governance_syntax"
if bash -n "$GOVERNANCE_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "alias_manifest_syntax"
if bash -n "$MANIFEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# `cd` is only replaced on opt-in; otherwise the helper is `cdh`.
# cd_probe [env...]: the alias names cd-init.aliases.sh defines.
cd_probe() {
  # shellcheck disable=SC2016
  env -i HOME="$HOME" PATH="/usr/bin:/bin" "$@" bash --norc --noprofile -c '
    shopt -s expand_aliases; source "$0" >/dev/null 2>&1
    for a in cd cdh; do alias "$a" >/dev/null 2>&1 && printf "%s " "$a"; done; true' "$CD_INIT_FILE"
}
test_start "cd_override_is_opt_in"
assert_equals "cdh |cd " "$(cd_probe)|$(cd_probe DOTFILES_ENABLE_CD_ALIAS=1)" "cd is aliased only with DOTFILES_ENABLE_CD_ALIAS=1"

# Policy tiers and deprecation enforcement are exercised end to end in
# test_alias_manifest_governance_fixtures.sh.

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$GOVERNANCE_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
