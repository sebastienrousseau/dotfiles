#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The Git Signing section of `dot doctor` (scripts/diagnostics/doctor.sh),
# which replaces `dot keys sign-check`: it reports the signing key and
# whether every commit is signed. Each case runs the real function against
# its own global git config.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOCTOR="$REPO_ROOT/scripts/diagnostics/doctor.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/doctor-signing.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.ssh" "$WORK/bin"
# A gpg that knows one key, so the result does not depend on the host.
printf '#!/bin/sh\n[ "$2" = KNOWN ]\n' >"$WORK/bin/gpg"
chmod +x "$WORK/bin/gpg"

# signing KEY=VALUE...: the section's report lines for a global git config
# holding the given settings.
signing() {
  local cfg="$WORK/gitconfig" kv
  : >"$cfg"
  for kv in "$@"; do git config --file "$cfg" "${kv%%=*}" "${kv#*=}"; done
  HOME="$WORK/home" GIT_CONFIG_GLOBAL="$cfg" PATH="$WORK/bin:$PATH" bash -c '
    _section() { :; }
    _ok() { echo "ok $1: $2"; }
    _warn() { echo "warn $1: $2"; }
    _fail() { echo "fail $1: $2"; }
    pretty_path() { printf "%s" "${1/#$HOME/\~}"; }
    eval "$(sed -n "/^_doctor_signing_key() {/,/^}/p;/^_doctor_git_signing() {/,/^}/p" "$1")"
    _doctor_git_signing' _ "$DOCTOR" | paste -sd '|' -
}

test_start "no_key_is_not_a_problem"
assert_equals "ok signing key: none configured (optional)" "$(signing)" "signing is opt-in, and nothing else is checked"

test_start "ssh_key"
touch "$WORK/home/.ssh/id_ed25519.pub"
assert_equals "ok signing key: ssh ~/.ssh/id_ed25519.pub|ok commit.gpgsign: every commit is signed" \
  "$(signing gpg.format=ssh user.signingkey="~/.ssh/id_ed25519.pub" commit.gpgsign=true)" "a key file that exists"
assert_equals "fail signing key: ssh key file not found: ~/.ssh/gone.pub|warn commit.gpgsign: off (git config --global commit.gpgsign true)" \
  "$(signing gpg.format=ssh user.signingkey="~/.ssh/gone.pub")" "a missing key file fails, and unsigned commits warn"
assert_contains "ok signing key" "$(signing gpg.format=ssh user.signingkey="ssh-ed25519 AAAAC3Nza")" "an inline public key"

test_start "gpg_key"
assert_contains "ok signing key: gpg KNOWN" "$(signing user.signingkey=KNOWN)" "a key in the keyring"
assert_contains "warn signing key: gpg key not in the keyring: OTHER" "$(signing user.signingkey=OTHER)" "one that is not"

test_start "doctor_runs_the_section"
assert_equals "1" "$(grep -c '^  _doctor_git_signing$' "$DOCTOR")" "listed once in the report order"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
