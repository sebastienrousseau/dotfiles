#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The secrets provider reports a failure as a failure. Each case here was a
# surviving mutant in the core mutation run: a missing age binary "stored"
# nothing successfully, a value age could not decrypt read as "not found",
# and a missing data file leaked awk's error.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROVIDER="$REPO_ROOT/scripts/lib/secrets_provider.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/secrets-fail.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
printf 'AGE-SECRET-KEY-STUB\n' >"$WORK/key.txt"

# A PATH with the tools the provider uses and no age binary.
NOAGE="$WORK/noage"
mkdir -p "$NOAGE"
for tool in bash sh cat mkdir chmod grep mktemp rm head mv touch sort dirname awk; do
  resolved="$(command -v "$tool" 2>/dev/null)" && ln -sf "$resolved" "$NOAGE/$tool"
done
printf '#!/bin/sh\necho age1stub\n' >"$NOAGE/age-keygen"
chmod +x "$NOAGE/age-keygen"

# provider <PATH> <function> [args...]: run one provider function.
provider() {
  local path="$1"
  shift
  HOME="$WORK" PATH="$path" DOTFILES_SECRETS_PROVIDER=plain-enc \
    DOT_SECRETS_HOME="$WORK/secrets" DOT_SECRETS_AGE_KEY="$WORK/key.txt" \
    bash -c 'source "$0"; "$@"' "$PROVIDER" "$@" >"$WORK/out" 2>"$WORK/err"
}

test_start "store_without_age_fails"
provider "$NOAGE" dot_secrets_set API_TOKEN s3cret
assert_equals "1" "$?" "set fails when age is not installed"
assert_file_contains "$WORK/err" "age not installed" "and says why"
assert_file_not_exists "$WORK/secrets/store/API_TOKEN.age" "nothing written"

test_start "undecryptable_value_is_a_provider_failure"
# age is present but cannot decrypt this value.
FAILAGE="$WORK/failage"
mkdir -p "$FAILAGE" "$WORK/secrets/store"
printf '#!/bin/sh\necho "age: no identity matched" >&2\nexit 1\n' >"$FAILAGE/age"
chmod +x "$FAILAGE/age"
printf 'not-really-age\n' >"$WORK/secrets/store/API_TOKEN.age"
provider "$FAILAGE:$PATH" dot_secrets_get API_TOKEN
assert_equals "1" "$?" "get exits 1, not 3 (not found)"
assert_file_contains "$WORK/err" "failed (rc=1) for key=API_TOKEN" \
  "the caller is told the provider failed"

test_start "bucket_keys_without_a_data_file_fails_quietly"
provider "$PATH" dot_secrets_bucket_keys "$WORK/no-such.toml" ai
assert_equals "1" "$?" "a missing data file is an error"
assert_equals "" "$(cat "$WORK/err")" "and nothing reaches stderr"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
