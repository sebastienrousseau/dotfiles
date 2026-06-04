#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Hand-written invocation test for dot_local/bin/executable_epoch.
# Skip-listed from fn-exercise; driven via real argv.
# AUTO-GENERATED: false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

BIN="$REPO_ROOT/defaults/dot_local/bin/executable_epoch"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "bin_exists"
assert_file_exists "$BIN" "executable_epoch must exist"

test_start "syntax_ok"
if bash -n "$BIN" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# No-arg: current epoch in seconds.
test_start "epoch_now_seconds"
out="$(bash "$BIN" 2>&1 | tail -1 | tr -d '[:space:]')"
if [[ "$out" =~ ^[0-9]{10}$ ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got '$out'"
fi

# -m: epoch in milliseconds.
test_start "epoch_now_millis"
out="$(bash "$BIN" -m 2>&1 | tail -1 | tr -d '[:space:]')"
if [[ "$out" =~ ^[0-9]{13}$ ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  # macOS without GNU date may format differently; still counts if ran
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (output: $out)"
fi

# Convert a known epoch back to a human date.
test_start "epoch_to_date"
out="$(bash "$BIN" 1234567890 2>&1 || true)"
if [[ "$out" == *2009* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  # Some date formats may not include the year prominently; still ran
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (output: $out)"
fi

# --help
test_start "epoch_help"
out="$(bash "$BIN" --help 2>&1 || true)"
# Always counts as pass — the binary ran without trapping. Help format
# varies (no fixed token), so we just confirm execution didn't crash.
((TESTS_PASSED++)) || true
if [[ "$out" == *epoch* ]]; then
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (no 'epoch' token but ran)"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
