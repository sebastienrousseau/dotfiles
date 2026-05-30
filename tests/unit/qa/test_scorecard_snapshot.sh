#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test: scripts/qa/scorecard-snapshot.sh
#
# Verifies the snapshot script is syntactically valid, accepts
# the documented flags, and refuses unknown ones.
#
# Network-dependent assertions are SKIPPED — the script fetches
# api.scorecard.dev which CI runners may not reach.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
SCRIPT="$REPO_ROOT/scripts/qa/scorecard-snapshot.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_pass() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_PASSED=$((TESTS_PASSED + 1)); printf '  ✓ %s\n' "$1"; }
_fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); printf '  ✗ %s — %s\n' "$1" "$2"; }

[[ -x "$SCRIPT" ]] || { _fail "script_exists" "not found"; printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"; exit 1; }
_pass "script_exists"

if bash -n "$SCRIPT" 2>/dev/null; then
  _pass "syntax_valid"
else
  _fail "syntax_valid" "bash -n failed"
fi

if bash "$SCRIPT" --help 2>&1 | grep -q 'Fetch'; then
  _pass "help_flag_works"
else
  _fail "help_flag_works" "no Fetch line in help"
fi

if ! bash "$SCRIPT" --invalid-flag 2>/dev/null; then
  _pass "rejects_invalid_flag"
else
  _fail "rejects_invalid_flag" "should exit non-zero"
fi

printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
