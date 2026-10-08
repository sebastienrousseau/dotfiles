#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The macOS Keychain provider must hand the secret to `security` on stdin
# (`security -i`), never as an argv word that `ps` shows to every user.
# Linux cannot run `security`, so a stub records argv and stdin instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROVIDER_LIB="$REPO_ROOT/scripts/lib/secrets_provider.sh"

WORK="$(mktemp -d -t secrets-keychain.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/home"

# Each call appends "ARGV: <args>", then "STDIN: <line>" per stdin line.
# SECURITY_STUB_FAIL=1 makes every call fail like a locked keychain would;
# SECURITY_STUB_MISSING=1 makes -i "succeed" while nothing was stored.
cat >"$WORK/stubs/security" <<STUB
#!/usr/bin/env bash
printf 'ARGV: %s\n' "\$*" >>"$WORK/security.log"
if [ "\${1:-}" = -i ]; then
  while IFS= read -r line || [ -n "\$line" ]; do
    printf 'STDIN: %s\n' "\$line" >>"$WORK/security.log"
  done
fi
[ "\${SECURITY_STUB_FAIL:-0}" = 1 ] && exit 1
[ "\${1:-}" = find-generic-password ] && [ "\${SECURITY_STUB_MISSING:-0}" = 1 ] && exit 44
exit 0
STUB
chmod +x "$WORK/stubs/security"

store() { # store KEY VALUE through the keychain provider in a clean shell
  rm -f "$WORK/security.log"
  HOME="$WORK/home" USER=tester DOTFILES_SECRETS_PROVIDER=macos-keychain \
    PATH="$WORK/stubs:$PATH" \
    bash -c 'source "$1"; shift; dot_secrets_set "$@"' _ "$PROVIDER_LIB" "$@" 2>&1
}

SECRET='s3cr3t-value'

test_start "keychain_secret_not_in_argv"
store API_TOKEN "$SECRET" >/dev/null
argv_lines="$(grep '^ARGV:' "$WORK/security.log" 2>/dev/null || true)"
assert_contains "ARGV: -i" "$argv_lines" "security is run in -i mode"
assert_false '[[ "$argv_lines" == *"$SECRET"* ]]' "the secret never appears on a security command line"

test_start "keychain_secret_sent_on_stdin"
stdin_lines="$(grep '^STDIN:' "$WORK/security.log" 2>/dev/null || true)"
assert_equals 'STDIN: add-generic-password -U -a "tester" -s "dotfiles.secret.API_TOKEN" -w "s3cr3t-value"' \
  "$stdin_lines" "security -i receives one quoted add-generic-password command"

test_start "keychain_value_quotes_and_backslashes_escaped"
store API_TOKEN 'a "q" b\c $x' >/dev/null
stdin_lines="$(grep '^STDIN:' "$WORK/security.log" 2>/dev/null || true)"
assert_contains '-w "a \"q\" b\\c $x"' "$stdin_lines" "double quotes and backslashes are escaped inside double quotes"

test_start "keychain_rejects_multiline_value"
rc=0
out="$(store API_TOKEN "$(printf 'line1\nline2')")" || rc=$?
assert_not_equals "0" "$rc" "a value with a newline is refused"
assert_contains "newline" "$out" "and the reason is given"
assert_equals "" "$(cat "$WORK/security.log" 2>/dev/null)" "security is never called"

test_start "keychain_failure_is_reported"
rm -rf "$WORK/home/.config"
rc=0
SECURITY_STUB_FAIL=1 store API_TOKEN "$SECRET" >/dev/null || rc=$?
assert_not_equals "0" "$rc" "a failing security call fails dot_secrets_set"
assert_equals "" "$(cat "$WORK/home/.config/dotfiles/secrets/index.txt" 2>/dev/null)" "and the key is not indexed"

test_start "keychain_silent_failure_is_caught"
rm -rf "$WORK/home/.config"
rc=0
out="$(SECURITY_STUB_MISSING=1 store API_TOKEN "$SECRET")" || rc=$?
assert_not_equals "0" "$rc" "an item missing after security -i fails dot_secrets_set"
assert_contains "failed to store secret in the keychain: API_TOKEN" "$out" "and says so"
assert_equals "" "$(cat "$WORK/home/.config/dotfiles/secrets/index.txt" 2>/dev/null)" "and the key is not indexed"

test_start "keychain_store_then_index"
rm -rf "$WORK/home/.config"
store API_TOKEN "$SECRET" >/dev/null
assert_equals "API_TOKEN" "$(cat "$WORK/home/.config/dotfiles/secrets/index.txt" 2>/dev/null)" "a stored key is indexed"
assert_contains "ARGV: find-generic-password -a tester -s dotfiles.secret.API_TOKEN" \
  "$(cat "$WORK/security.log")" "the stored item is looked up by account and service"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
