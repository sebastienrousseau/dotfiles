#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Secret key names become file names (<store>/<key>.age) and keychain
# service names, so they may not contain path separators or start with '-'
# or '.'. Bucket keys are also emitted as `export KEY=...` lines that shells
# source, so those must be shell identifiers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROVIDER_LIB="$REPO_ROOT/scripts/lib/secrets_provider.sh"

WORK="$(mktemp -d -t secrets-keys.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/home"

# A pass stub that records what it was asked to store.
cat >"$WORK/stubs/pass" <<STUB
#!/bin/sh
[ "\$1" = insert ] && { cat >/dev/null; echo "insert \$*" >>"$WORK/pass.log"; exit 0; }
[ "\$1" = show ] && { echo "value-for-\$2"; exit 0; }
exit 0
STUB
chmod +x "$WORK/stubs/pass"

sec() { # run a provider function in a clean shell
  HOME="$WORK/home" DOTFILES_SECRETS_PROVIDER=pass PATH="$WORK/stubs:$PATH" \
    bash -c 'source "$1"; shift; "$@"' _ "$PROVIDER_LIB" "$@" 2>&1
}

test_start "secrets_accepts_identifier_key"
sec dot_secrets_set OPENAI_API_KEY value >/dev/null
assert_contains "dotfiles/OPENAI_API_KEY" "$(cat "$WORK/pass.log" 2>/dev/null)" "a plain identifier is stored"

test_start "secrets_accepts_hyphenated_key"
rm -f "$WORK/pass.log"
sec dot_secrets_set my-api.key value >/dev/null
assert_contains "dotfiles/my-api.key" "$(cat "$WORK/pass.log" 2>/dev/null)" "existing hyphen/dot names stay usable"

for bad in '../escape' 'A/B' '.hidden' 'X;touch' 'has space' '-flag' ''; do
  test_start "secrets_set_rejects_${bad:-empty}"
  rm -f "$WORK/pass.log"
  sec dot_secrets_set "$bad" value >/dev/null
  rc=$?
  if [[ "$rc" -ne 0 && ! -s "$WORK/pass.log" ]]; then
    assert_exit_code 0 "true"
  else
    assert_exit_code 0 "false  # key '$bad' accepted (rc=$rc)"
  fi
done

test_start "secrets_get_rejects_path_key"
sec dot_secrets_get '../escape' >/dev/null
assert_not_equals "0" "$?" "a path-like key is not looked up"

# `dot secrets load` turns bucket keys into `export KEY=value` lines that
# shells source; a crafted key in the data file must never be listed.
test_start "secrets_bucket_keys_keep_valid"
cat >"$WORK/data.toml" <<'TOML'
[secrets]
ai = ["GOOD_KEY", "BAD;touch /tmp/pwned", "../escape", "not-an-identifier"]
TOML
keys="$(sec dot_secrets_bucket_keys "$WORK/data.toml" ai)"
assert_contains "GOOD_KEY" "$keys" "valid keys are listed"
test_start "secrets_bucket_keys_drop_invalid"
listed="$(HOME="$WORK/home" bash -c 'source "$1"; dot_secrets_bucket_keys "$2" ai' _ "$PROVIDER_LIB" "$WORK/data.toml" 2>/dev/null)"
assert_equals "GOOD_KEY" "$listed" "only the valid key is listed on stdout"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
