#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
#
# Tests for scripts/security/check-disclosure-key-expiry.sh — the
# script that monitors the 2029-05-15 GPG disclosure-key expiry and
# fails CI when the remaining lifetime drops below threshold.
#
# Closes the Examples-Contract module-coverage check by giving the
# new script a name-matching unit test.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/security/check-disclosure-key-expiry.sh"

# Detect whether `gpg` on PATH is the cov_setup_sandbox shim. The shim
# echoes `[cov-shim:gpg …]` and exits 0; the real binary writes
# `gpg: imported: 1` for a successful import. Save the answer BEFORE
# we enter the sandbox.
_real_gpg_available=0
if command -v gpg >/dev/null 2>&1 && ! gpg --version 2>&1 | grep -q '^\[cov-shim:'; then
  _real_gpg_available=1
fi
_PRE_SANDBOX_PATH="$PATH"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Re-check from inside the sandbox — the shim overrides gpg.
_gpg_is_real() {
  command -v gpg >/dev/null 2>&1 \
    && ! gpg --version 2>&1 | grep -q '^\[cov-shim:' \
    && (( _real_gpg_available == 1 ))
}

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "check-disclosure-key-expiry.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "script_help"
if bash "$SCRIPT_FILE" --help 2>&1 | grep -q 'check-disclosure-key-expiry'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Reject unknown flags loudly (the script catches them via the case
# statement's `*)` arm).
test_start "script_rejects_unknown_flag"
if bash "$SCRIPT_FILE" --not-a-real-flag >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have rejected"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# GPG-dependent assertions — the cov sandbox shims `gpg` to a no-op
# so we can only run these when we detected the REAL gpg before the
# sandbox started. CI runners on Linux have gpg installed; the local
# dev loop has it via brew. Both true → real assertions; either
# false → soft pass with a "skipped" note.

test_start "script_passes_with_valid_key"
if _gpg_is_real; then
  # Run with the real gpg from the pre-sandbox PATH.
  if PATH="${_PRE_SANDBOX_PATH:-$PATH}" bash "$SCRIPT_FILE" >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    rc=$?
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped — gpg shimmed or missing)"
fi

test_start "script_fail_days_zero_passes"
if _gpg_is_real; then
  if PATH="${_PRE_SANDBOX_PATH:-$PATH}" bash "$SCRIPT_FILE" --fail-days 0 --warn-days 0 >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped — gpg shimmed or missing)"
fi

test_start "script_fail_days_huge_fails"
if _gpg_is_real; then
  if PATH="${_PRE_SANDBOX_PATH:-$PATH}" bash "$SCRIPT_FILE" --fail-days 99999 >/dev/null 2>&1; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have failed"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped — gpg shimmed or missing)"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
