#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The plain-enc provider must refuse to "store" a secret it cannot
# encrypt. Found by mutation testing (S5): with the missing-key check
# returning 0, `dot secrets set` reported success, indexed the key and
# stored nothing, and no test noticed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/secrets-plain.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
# age and age-keygen present, so only the key check can refuse.
printf '#!/bin/sh\ncat >/dev/null\nexit 0\n' >"$WORK/bin/age"
printf '#!/bin/sh\necho age1stub\n' >"$WORK/bin/age-keygen"
chmod +x "$WORK/bin/age" "$WORK/bin/age-keygen"

set_secret() { # set_secret <key-file> <key> <value>
  HOME="$WORK" PATH="$WORK/bin:$PATH" DOTFILES_SECRETS_PROVIDER=plain-enc \
    DOT_SECRETS_HOME="$WORK/secrets" DOT_SECRETS_AGE_KEY="$1" \
    bash -c 'source "$0"; dot_secrets_set "$1" "$2"' \
    "$REPO_ROOT/scripts/lib/secrets_provider.sh" "$2" "$3" >"$WORK/out" 2>&1
}

test_start "plain_enc_without_age_key_fails"
set_secret "$WORK/missing-key.txt" API_TOKEN s3cret
assert_equals "1" "$?" "set fails when the age key is missing"
assert_file_contains "$WORK/out" "age key not found: $WORK/missing-key.txt" "names the missing key"
assert_file_not_exists "$WORK/secrets/store/API_TOKEN.age" "nothing written"
indexed=no
grep -qx API_TOKEN "$WORK/secrets/index.txt" 2>/dev/null && indexed=yes
assert_equals "no" "$indexed" "key not indexed"

test_start "plain_enc_with_age_key_stores_and_indexes"
printf 'AGE-SECRET-KEY-STUB\n' >"$WORK/key.txt"
set_secret "$WORK/key.txt" API_TOKEN s3cret
assert_equals "0" "$?" "set succeeds with a key"
assert_equals "1" "$(grep -cx API_TOKEN "$WORK/secrets/index.txt")" "key indexed once"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
