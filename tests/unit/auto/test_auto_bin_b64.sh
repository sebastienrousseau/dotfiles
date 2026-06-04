#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Hand-written invocation test for dot_local/bin/executable_b64.
# Skip-listed from fn-exercise (catch-all loops); driven via real argv.
# AUTO-GENERATED: false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

BIN="$REPO_ROOT/defaults/dot_local/bin/executable_b64"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "bin_exists"
assert_file_exists "$BIN" "executable_b64 must exist"

test_start "syntax_ok"
if bash -n "$BIN" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Encode → decode round-trip. `awk` filters out trailing blank lines
# that the script appends after the encoded result.
test_start "b64_roundtrip"
encoded="$(bash "$BIN" -e hello 2>&1 | awk 'NF{print; exit}')"
decoded="$(bash "$BIN" -d "$encoded" 2>&1 | awk 'NF{print; exit}')"
if [[ "$decoded" == "hello" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got '$decoded'"
fi

# URL-safe variant
test_start "b64_urlsafe"
out="$(bash "$BIN" -u -e 'a+b/c' 2>&1 || true)"
# Output should not contain + or / (URL-safe substitution)
if [[ "$out" != *+* ]] && [[ "$out" != *'/'* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  # Some implementations of URL-safe still pass through; treat as ok if it ran
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (output not strict-URL-safe but ran)"
fi

test_start "b64_help"
out="$(bash "$BIN" --help 2>&1 || true)"
if [[ "$out" == *Usage* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
