#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Hand-written invocation test for dot_local/bin/executable_hash.
# The generic fn-exercise helper skip-lists this script because its
# arg parser doesn't shift in the catch-all branch and trips the
# exit() override. Driving the binary directly via real argv tests
# every algorithm + flag without that hazard.
#
# AUTO-GENERATED: false (hand-written, do not regenerate)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

HASH_BIN="$REPO_ROOT/defaults/dot_local/bin/executable_hash"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "bin_exists"
assert_file_exists "$HASH_BIN" "executable_hash must exist"

test_start "syntax_ok"
if bash -n "$HASH_BIN" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# --- one row per algorithm so each `case` arm in main fires
for spec in "-m hello md5" "-1 hello sha1" "-2 hello sha256" "-5 hello sha512"; do
  read -r flag input algo <<< "$spec"
  test_start "hash_${algo}"
  out="$(bash "$HASH_BIN" "$flag" "$input" 2>&1 || true)"
  # Hash output is 32/40/64/128 hex chars depending on algo;
  # we only sanity-check the run produced *some* hex output.
  if [[ "$out" =~ [a-f0-9]{8,} ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no hex in output"
  fi
done

# --all prints every algorithm
test_start "hash_all"
out="$(bash "$HASH_BIN" -a hello 2>&1 || true)"
if [[ "$out" == *MD5* ]] && [[ "$out" == *SHA256* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# --help exits 0 and prints usage
test_start "hash_help"
out="$(bash "$HASH_BIN" -h 2>&1 || true)"
if [[ "$out" == *Usage* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# File mode — hash an actual file
test_start "hash_file"
_tmp="$(mktemp -t hash-test.XXXXXX)"
printf 'test content\n' > "$_tmp"
out="$(bash "$HASH_BIN" -f "$_tmp" 2>&1 || true)"
rm -f "$_tmp"
if [[ "$out" =~ [a-f0-9]{16,} ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Verify mode — compute then verify
test_start "hash_verify"
hash="$(bash "$HASH_BIN" -2 hello 2>&1 | tr -d '[:space:]' || true)"
if bash "$HASH_BIN" -c "$hash" hello >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
