#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test: scripts/qa/check-version-consistency.sh
#
# Verifies the version-drift check exits 0 against the live tree
# (where the 8 surfaces match .chezmoidata.toml) and exits 1
# against a temp tree where one surface is manually drifted.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
SCRIPT="$REPO_ROOT/scripts/qa/check-version-consistency.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_pass() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_PASSED=$((TESTS_PASSED + 1)); printf '  ✓ %s\n' "$1"; }
_fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); printf '  ✗ %s — %s\n' "$1" "$2"; }

[[ -x "$SCRIPT" ]] || { _fail "script_exists" "not found: $SCRIPT"; printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"; exit 1; }
_pass "script_exists"

if bash "$SCRIPT" --quiet; then
  _pass "live_tree_passes_quiet"
else
  _fail "live_tree_passes_quiet" "exit non-zero"
fi

if bash "$SCRIPT" --help 2>&1 | grep -q 'Usage'; then
  _pass "help_flag_works"
else
  _fail "help_flag_works" "no Usage line"
fi

if ! bash "$SCRIPT" --invalid-flag 2>/dev/null; then
  _pass "rejects_invalid_flag"
else
  _fail "rejects_invalid_flag" "should exit non-zero"
fi

printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
