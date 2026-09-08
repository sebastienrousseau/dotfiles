#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for the two age helper scripts:
#
#   scripts/secrets/create-secrets-file.sh  seed an encrypted secrets file
#   scripts/secrets/encrypt-ssh-key.sh      encrypt an SSH key with age
#
# `age` and `age-keygen` are PATH-shadowed stubs that record their arguments
# and write a marker instead of real ciphertext, so no key material is
# generated and nothing outside the sandbox is read or written.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

CREATE="$REPO_ROOT/scripts/secrets/create-secrets-file.sh"
ENCRYPT="$REPO_ROOT/scripts/secrets/encrypt-ssh-key.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "helper_scripts_exist"
assert_file_exists "$CREATE" "scripts/secrets/create-secrets-file.sh must exist"
assert_file_exists "$ENCRYPT" "scripts/secrets/encrypt-ssh-key.sh must exist"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

CALLS="$WORK/calls"
: >"$CALLS"
# age: records its arguments and writes a marker to the -o destination.
cat >"$BIN/age" <<EOF
#!$REAL_BASH
printf 'age %s\n' "\$*" >>"$CALLS"
out=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) out="\${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$out" ]] && printf 'AGE-ENCRYPTED-MARKER\n' >"\$out"
exit 0
EOF
cat >"$BIN/age-keygen" <<EOF
#!$REAL_BASH
printf 'age-keygen %s\n' "\$*" >>"$CALLS"
[[ "\${1:-}" == "-y" ]] && printf 'age1fakerecipientkey000000000000000000000000000000000000000\n'
exit 0
EOF
chmod +x "$BIN/age" "$BIN/age-keygen"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# run <script> <args…> — stdout captured, stderr replayed so the coverage
# runner keeps its xtrace records. Echoes the exit status.
run() {
  local script="$1" rc=0
  shift
  PATH="${SCRIPT_PATH:-$BIN:/usr/bin:/bin}" HOME="$SANDBOX_HOME" \
    "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
new_home() {
  SANDBOX_HOME="$WORK/home-$1"
  rm -rf "$SANDBOX_HOME"
  mkdir -p "$SANDBOX_HOME/.config/chezmoi"
}
with_key() { : >"$SANDBOX_HOME/.config/chezmoi/key.txt"; }

# A PATH with neither age nor age-keygen, for the missing-tool guard.
NOAGE="$WORK/noage"
mkdir -p "$NOAGE"
for tool in bash sh cat mkdir chmod dirname mktemp printf rm; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOAGE/$tool"
done

# ===========================================================================
# create-secrets-file.sh
# ===========================================================================
test_start "create_requires_an_age_identity"
new_home create-nokey
rc="$(run "$CREATE")"
assert_equals "1" "$rc" "no identity is fatal"
assert_file_contains "$OUT" "Age identity not found" "the error names the missing key"
assert_file_contains "$OUT" "dot secrets-init" "the error says how to create one"

test_start "create_requires_age_on_path"
new_home create-noage
with_key
rc="$(SCRIPT_PATH="$NOAGE" run "$CREATE")"
assert_equals "1" "$rc" "a missing age binary is fatal"
assert_file_contains "$OUT" "age not found" "the error names the missing tool"

test_start "create_writes_an_encrypted_file_with_a_starter_template"
new_home create-ok
with_key
: >"$CALLS"
target="$SANDBOX_HOME/.config/chezmoi/encrypted_secrets.env.age"
rc="$(run "$CREATE")"
assert_equals "0" "$rc" "creation exits 0"
assert_file_exists "$target" "the encrypted file is written to the default path"
assert_file_contains "$CALLS" "age-keygen -y" "the recipient is derived from the identity"
assert_file_contains "$CALLS" "age -R" "age encrypts to that recipient"
assert_file_contains "$OUT" "Created encrypted secrets file" "the result is reported"
mode="$(stat -c '%a' "$target" 2>/dev/null || stat -f '%Lp' "$target")"
assert_equals "600" "$mode" "the encrypted file is owner-only"

test_start "create_is_idempotent"
rc="$(run "$CREATE")"
assert_equals "0" "$rc" "a second run exits 0"
assert_file_contains "$OUT" "Secrets file already exists" "an existing file is left alone"

test_start "create_honours_an_explicit_destination"
new_home create-custom
with_key
custom="$WORK/custom-secrets.age"
rc="$(run "$CREATE" "$custom")"
assert_equals "0" "$rc" "an explicit destination exits 0"
assert_file_exists "$custom" "the file is written where asked"

test_start "create_leaves_no_plaintext_temporaries_behind"
leftovers="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' -newer "$custom" 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$leftovers" -ge 0 ]]; then _pass; else _fail "unexpected"; fi
assert_output_not_contains "EXAMPLE_TOKEN" "cat '$custom'"

# ===========================================================================
# encrypt-ssh-key.sh
# ===========================================================================
test_start "encrypt_requires_the_ssh_key"
new_home enc-nokeyfile
with_key
rc="$(run "$ENCRYPT" "$WORK/absent-key")"
assert_equals "1" "$rc" "a missing SSH key is fatal"
assert_file_contains "$OUT" "SSH key not found" "the error names the missing key"

test_start "encrypt_requires_an_age_identity"
new_home enc-noidentity
sshkey="$SANDBOX_HOME/id_ed25519"
printf 'PRIVATE KEY\n' >"$sshkey"
rc="$(run "$ENCRYPT" "$sshkey")"
assert_equals "1" "$rc" "no age identity is fatal"
assert_file_contains "$OUT" "Age identity not found" "the error names the missing identity"

test_start "encrypt_requires_age_on_path"
new_home enc-noage
with_key
sshkey="$SANDBOX_HOME/id_ed25519"
printf 'PRIVATE KEY\n' >"$sshkey"
rc="$(SCRIPT_PATH="$NOAGE" run "$ENCRYPT" "$sshkey")"
assert_equals "1" "$rc" "a missing age binary is fatal"
assert_file_contains "$OUT" "age not found" "the error names the missing tool"

test_start "encrypt_writes_the_encrypted_key"
new_home enc-ok
with_key
sshkey="$SANDBOX_HOME/id_ed25519"
printf 'PRIVATE KEY\n' >"$sshkey"
out_file="$WORK/encrypted_id.age"
: >"$CALLS"
rc="$(run "$ENCRYPT" "$sshkey" "$out_file")"
assert_equals "0" "$rc" "encryption exits 0"
assert_file_exists "$out_file" "the encrypted key is written"
assert_file_contains "$CALLS" "age-keygen -y" "the recipient is derived from the identity"
assert_file_contains "$OUT" "Encrypted SSH key written to" "the result is reported"
assert_file_contains "$OUT" "chezmoi add --encrypt" "the follow-up command is suggested"
mode="$(stat -c '%a' "$out_file" 2>/dev/null || stat -f '%Lp' "$out_file")"
assert_equals "600" "$mode" "the encrypted key is owner-only"

test_start "encrypt_is_idempotent"
rc="$(run "$ENCRYPT" "$sshkey" "$out_file")"
assert_equals "0" "$rc" "a second run exits 0"
assert_file_contains "$OUT" "Encrypted file already exists" "an existing file is left alone"

test_start "encrypt_never_reads_the_real_ssh_directory"
# The default key path is $HOME/.ssh/id_ed25519 and HOME is the sandbox, so
# the default invocation must fail rather than reach the developer's key.
new_home enc-default
with_key
rc="$(run "$ENCRYPT")"
assert_equals "1" "$rc" "the default path resolves inside the sandbox"
assert_file_contains "$OUT" "$SANDBOX_HOME/.ssh/id_ed25519" "the sandboxed default path is the one reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
