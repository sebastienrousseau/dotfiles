#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for the secrets provider from scripts/lib/secrets_provider.sh.
# Mocks keychain/pass/age commands to verify provider detection order and
# the index, store, and get/set dispatch logic.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

SECRETS_FILE="$REPO_ROOT/scripts/lib/secrets_provider.sh"
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
assert_equals "1" "$?" "dot_secrets_get with no provider should return exit code 1"

# Cleanup
rm -rf "$_TMP_SECRETS"
mock_cleanup

echo ""
echo "secrets provider behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
