#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for the secrets provider from scripts/lib/secrets_provider.sh.
# Mocks keychain/pass/age commands to verify provider detection order and
# the index, store, and get/set dispatch logic.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SECRETS_FILE="$REPO_ROOT/scripts/lib/secrets_provider.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "SKIP: secrets_provider.sh not found at $SECRETS_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

# secrets_provider.sh uses set -euo pipefail; source tolerantly.
# We also override the globals to point at temp directories.
_TMP_SECRETS=$(portable_mktemp_dir)
export DOT_SECRETS_HOME="$_TMP_SECRETS"
export DOT_SECRETS_STORE_DIR="$_TMP_SECRETS/store"
export DOT_SECRETS_INDEX_FILE="$_TMP_SECRETS/index.txt"
export DOT_SECRETS_AGE_KEY="$_TMP_SECRETS/key.txt"

source "$SECRETS_FILE" 2>/dev/null || {
  echo "SKIP: could not source secrets_provider.sh"
  echo "RESULTS:0:0:0"
  exit 0
}
set +e # tests need to handle errors explicitly

mock_init

# ──────────────────────────────────────────────────────────────────────────────
# Helper: set environment to "no provider available"
# ──────────────────────────────────────────────────────────────────────────────
_clear_provider_env() {
  unset DOTFILES_SECRETS_PROVIDER 2>/dev/null || true
  # Hide all known provider binaries from PATH:
  # security, pass, age are mocked via MOCK_BIN_DIR; clear them.
  rm -f "$MOCK_BIN_DIR/security" "$MOCK_BIN_DIR/pass" "$MOCK_BIN_DIR/age" \
    "$MOCK_BIN_DIR/age-keygen" 2>/dev/null || true
  # Ensure we're on non-darwin so the OSTYPE guard doesn't trip.
  export OSTYPE="linux-gnu"
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. DOTFILES_SECRETS_PROVIDER override bypasses auto-detection
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_provider_explicit_override"
export DOTFILES_SECRETS_PROVIDER="my-custom-provider"
result=$(dot_secrets_provider)
assert_equals "my-custom-provider" "$result" "explicit provider override should be returned as-is"
unset DOTFILES_SECRETS_PROVIDER

# ──────────────────────────────────────────────────────────────────────────────
# 2. Auto-detection: macOS keychain takes priority when OSTYPE=darwin* and
#    'security' command is available
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_provider_macos_keychain_priority"
_clear_provider_env
mock_command "security" ""
export OSTYPE="darwin21"
result=$(dot_secrets_provider)
assert_equals "macos-keychain" "$result" "macOS keychain should be detected when OSTYPE=darwin* and security exists"
_clear_provider_env

# ──────────────────────────────────────────────────────────────────────────────
# 3. Auto-detection: 'pass' is chosen when security is absent and pass exists
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_provider_pass_second_priority"
_clear_provider_env
# No 'security' in MOCK_BIN_DIR; add 'pass'.
mock_command "pass" ""
result=$(dot_secrets_provider)
assert_equals "pass" "$result" "'pass' should be chosen when security is absent"
_clear_provider_env

# ──────────────────────────────────────────────────────────────────────────────
# 4. Auto-detection: 'plain-enc' (age) when only age is available and key exists
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_provider_age_third_priority"
_clear_provider_env
mock_command "age" ""
# Create a fake age key file
echo "AGE-SECRET-KEY-FAKE" >"$DOT_SECRETS_AGE_KEY"
result=$(dot_secrets_provider)
assert_equals "plain-enc" "$result" "'plain-enc' should be chosen when age is available with key"
rm -f "$DOT_SECRETS_AGE_KEY"
_clear_provider_env

# ──────────────────────────────────────────────────────────────────────────────
# 5. Auto-detection: 'none' when no provider is available
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_provider_none_fallback"
_clear_provider_env
result=$(dot_secrets_provider)
assert_equals "none" "$result" "should fall back to 'none' when no provider is available"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Age provider requires age key file to exist (not just the binary)
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_provider_age_requires_key_file"
_clear_provider_env
mock_command "age" ""
# No key file present → should NOT select plain-enc
rm -f "$DOT_SECRETS_AGE_KEY"
result=$(dot_secrets_provider)
assert_not_equals "plain-enc" "$result" "age provider should not be selected without key file"
_clear_provider_env

# ──────────────────────────────────────────────────────────────────────────────
# 7. dot_secrets_ensure_layout creates required directories and files
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_ensure_layout_creates_dirs"
rm -rf "$_TMP_SECRETS"
dot_secrets_ensure_layout
assert_dir_exists "$DOT_SECRETS_STORE_DIR" "ensure_layout should create store directory"
assert_file_exists "$DOT_SECRETS_INDEX_FILE" "ensure_layout should create index file"

# ──────────────────────────────────────────────────────────────────────────────
# 8. dot_secrets_index_add adds a key to the index (no duplicates)
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_index_add_no_duplicate"
>"$DOT_SECRETS_INDEX_FILE"
dot_secrets_index_add "my-key"
dot_secrets_index_add "my-key" # second call — should not duplicate
count=$(grep -cxF "my-key" "$DOT_SECRETS_INDEX_FILE" || true)
assert_equals "1" "$count" "index should contain 'my-key' exactly once after two adds"

# ──────────────────────────────────────────────────────────────────────────────
# 9. dot_secrets_index_list returns sorted unique keys
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_index_list_sorted_unique"
>"$DOT_SECRETS_INDEX_FILE"
printf "zebra\nalpha\nalpha\nbeta\n" >>"$DOT_SECRETS_INDEX_FILE"
result=$(dot_secrets_index_list)
expected="alpha
beta
zebra"
assert_equals "$expected" "$result" "index_list should return sorted unique keys"

# ──────────────────────────────────────────────────────────────────────────────
# 10. dot_secrets_set returns error when no provider is available
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_set_no_provider_returns_error"
_clear_provider_env
output=$(dot_secrets_set "some-key" "some-value" 2>&1)
assert_equals "1" "$?" "dot_secrets_set with no provider should return exit code 1"
assert_contains "No supported secrets provider" "$output" "should mention 'No supported secrets provider'"

# ──────────────────────────────────────────────────────────────────────────────
# 11. dot_secrets_get returns error when no provider available
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_get_no_provider_returns_error"
_clear_provider_env
dot_secrets_get "some-key" 2>/dev/null
# R3 N6 split the exit codes: rc=1 (bad usage), rc=2 (no provider),
# rc=3 (provider returned empty). "No provider configured" is rc=2.
assert_equals "2" "$?" "dot_secrets_get with no provider should return exit code 2 (rc=1 was the pre-N6 behavior)"

# ──────────────────────────────────────────────────────────────────────────────
# 12. plain-enc: a successful write must report success
#
# Regression: dot_secrets_store_plain_enc set `trap 'rm -f "$tmp_rec"' RETURN`
# on a variable local to itself. A RETURN trap set inside a function fires
# again when its CALLER returns — dot_secrets_set — by which point tmp_rec is
# out of scope, so under `set -u` the whole call aborted with
# "tmp_rec: unbound variable" AFTER the encrypted file had been written.
# `dot secrets set` exited non-zero on a write that had in fact succeeded, and
# the key never reached the index because index_add came after the store.
#
# Run in a child shell with `set -euo pipefail` — this file runs with `set +e`,
# which is exactly the condition that hides the bug.
# ──────────────────────────────────────────────────────────────────────────────
test_start "secrets_set_plain_enc_reports_a_successful_write"
_PLAIN_TMP="$(portable_mktemp_dir)"
mkdir -p "$_PLAIN_TMP/bin"
cat >"$_PLAIN_TMP/bin/age-keygen" <<'SHIM'
#!/usr/bin/env bash
[[ "${1:-}" == "-y" ]] && printf 'age1testrecipient\n'
exit 0
SHIM
cat >"$_PLAIN_TMP/bin/age" <<'SHIM'
#!/usr/bin/env bash
out=""
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *) shift ;;
  esac
done
if [[ -n "$out" ]]; then
  cat >"$out"
else
  cat >/dev/null
fi
exit 0
SHIM
chmod +x "$_PLAIN_TMP/bin/age-keygen" "$_PLAIN_TMP/bin/age"
printf 'AGE-SECRET-KEY-TEST\n' >"$_PLAIN_TMP/key.txt"

mkdir -p "$_PLAIN_TMP/tmp"
_plain_out="$(
  PATH="$_PLAIN_TMP/bin:$PATH" \
    TMPDIR="$_PLAIN_TMP/tmp" \
    DOTFILES_SECRETS_PROVIDER=plain-enc \
    DOT_SECRETS_HOME="$_PLAIN_TMP/secrets" \
    DOT_SECRETS_STORE_DIR="$_PLAIN_TMP/secrets/store" \
    DOT_SECRETS_INDEX_FILE="$_PLAIN_TMP/secrets/index.txt" \
    DOT_SECRETS_AGE_KEY="$_PLAIN_TMP/key.txt" \
    bash -c 'set -euo pipefail; source "$1"; dot_secrets_set PLAIN_KEY plain-value' \
    _ "$SECRETS_FILE" 2>&1
)"
_plain_rc=$?
assert_equals "0" "$_plain_rc" "a successful plain-enc write must exit 0"
assert_output_not_contains "unbound variable" "printf '%s' \"\$_plain_out\""
assert_file_exists "$_PLAIN_TMP/secrets/store/PLAIN_KEY.age" "the encrypted file is written"
assert_file_contains "$_PLAIN_TMP/secrets/index.txt" "PLAIN_KEY" \
  "the key reaches the index, which only happens if the store call returned"

test_start "secrets_set_plain_enc_reports_a_failing_encryption"
# The trap that used to clean up also swallowed nothing useful: with it gone,
# a failing age-keygen or age must be reported rather than assumed to work,
# or a failed encryption would look exactly like a stored secret.
cat >"$_PLAIN_TMP/bin/age" <<'SHIM'
#!/usr/bin/env bash
exit 3
SHIM
chmod +x "$_PLAIN_TMP/bin/age"
_fail_out="$(
  PATH="$_PLAIN_TMP/bin:$PATH" \
    TMPDIR="$_PLAIN_TMP/tmp" \
    DOTFILES_SECRETS_PROVIDER=plain-enc \
    DOT_SECRETS_HOME="$_PLAIN_TMP/secrets" \
    DOT_SECRETS_STORE_DIR="$_PLAIN_TMP/secrets/store" \
    DOT_SECRETS_INDEX_FILE="$_PLAIN_TMP/secrets/index.txt" \
    DOT_SECRETS_AGE_KEY="$_PLAIN_TMP/key.txt" \
    bash -c 'set -euo pipefail; source "$1"; dot_secrets_set FAIL_KEY v' \
    _ "$SECRETS_FILE" 2>&1
)"
_fail_rc=$?
assert_not_equals "0" "$_fail_rc" "a failing age must not report success"
assert_output_not_contains "FAIL_KEY" "cat '$_PLAIN_TMP/secrets/index.txt'"

test_start "secrets_set_plain_enc_leaves_no_recipient_file_behind"
# The recipient file the store writes is a temporary; dropping the RETURN
# trap must not mean dropping the cleanup. TMPDIR was private to the child,
# so anything left there is ours.
_leftover="$(find "$_PLAIN_TMP/tmp" -type f 2>/dev/null | wc -l | tr -d ' ')"
assert_equals "0" "$_leftover" "the temporary recipient file is removed"
rm -rf "$_PLAIN_TMP"

# Cleanup
rm -rf "$_TMP_SECRETS"
mock_cleanup

echo ""
echo "secrets provider behavioral tests completed."
# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$SECRETS_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
