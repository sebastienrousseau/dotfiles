#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The attest, secret and fleet entries (ADR-020 N2, P2.1) turn each
# spelling their manifest declares into what implements it: a script, or
# a subcommand of the module the plugin keeps in libexec/. bash is
# PATH-shadowed by a shim that records those hand-offs instead of running
# them. The last cases go through bin/dot: with `fallback`, a word the
# table does not take reaches the entry; without it, it exits 127.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-entry-map.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"

cat >"$WORK/bin/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  */plugins/*/libexec/*.sh) printf 'module %s %s\n' "\${1##*/libexec/}" "\${*:2}"; exit "\${DISPATCH_RC:-0}" ;;
  */scripts/dot/commands/*) ;;
  */scripts/*) printf 'ran %s %s\n' "\${1##*/scripts/}" "\${*:2}"; exit "\${DISPATCH_RC:-0}" ;;
esac
exec "$REAL_BASH" "\$@"
EOF
chmod +x "$WORK/bin/bash"

# run <file> <args...> — run a file with the shim on PATH; sets RC and OUT
# (the first module or script line it recorded).
run() {
  local file="$1"
  shift
  RC=0
  (cd "$WORK" && HOME="$WORK/home" XDG_STATE_HOME="$WORK/home/.local/state" \
    DOTFILES_SHOW_LOGO=0 NO_COLOR=1 TERM=dumb PATH="$WORK/bin:/usr/bin:/bin" \
    "$REAL_BASH" "$file" "$@") >"$WORK/out" 2>"$WORK/err" </dev/null || RC=$?
  OUT="$(grep -E '^(module|ran) ' "$WORK/out" | head -1)"
}

# expect <entry> <words> <recorded line> — the entry hands the words on as
# the line says, and its status is the hand-off's.
expect() {
  # shellcheck disable=SC2086 # words
  run "$REPO_ROOT/plugins/$1/dot-$1" $2
  assert_equals "$3" "$OUT" "dot $1 $2"
  assert_equals "0" "$RC" "dot $1 $2 exits 0"
}

test_start "attest_spellings_choose_the_mode"
expect attest "show --json" "ran diagnostics/workstation-attestation.sh --json"
expect attest "export" "ran diagnostics/workstation-attestation.sh --write"
expect attest "verify evidence.json" "ran diagnostics/workstation-attestation.sh --verify evidence.json"
expect attest "" "ran diagnostics/workstation-attestation.sh "
expect attest "--json" "ran diagnostics/workstation-attestation.sh --json"

test_start "secret_spellings_become_module_subcommands"
expect secret "init" "module secrets.sh secrets-init"
expect secret "new" "module secrets.sh secrets-create"
expect secret "edit" "module secrets.sh secrets edit"
expect secret "list" "module secrets.sh secrets list"
expect secret "show KEY" "module secrets.sh secrets get KEY"
expect secret "set KEY" "module secrets.sh secrets set KEY"
expect secret "export --shell fish" "module secrets.sh secrets load --shell fish"
expect secret "provider show" "module secrets.sh secrets provider"
expect secret "key new" "module secrets.sh ssh-key"
expect secret "cert list" "module secrets.sh ssh-cert status"
expect secret "cert new --ttl 1h" "module secrets.sh ssh-cert issue --ttl 1h"
expect secret "cert remove" "module secrets.sh ssh-cert revoke"
expect secret "check" "ran diagnostics/secret-governance.sh "

test_start "secret_refuses_an_undeclared_spelling"
for words in "" "status" "key list" "provider set" "bogus"; do
  # shellcheck disable=SC2086 # words
  run "$REPO_ROOT/plugins/secret/dot-secret" $words
  assert_equals "127" "$RC" "dot secret $words is not built in the entry"
  assert_equals "" "$OUT" "dot secret $words ran nothing"
done

test_start "fleet_spellings_become_module_subcommands"
expect fleet "status" "module fleet.sh fleet status"
expect fleet "apply --dry-run" "module fleet.sh fleet apply --dry-run"
expect fleet "push web-1" "module fleet.sh fleet push web-1"
expect fleet "drift show" "module fleet.sh fleet drift"
expect fleet "namespace list" "module fleet.sh fleet namespace show"
expect fleet "log show" "module fleet.sh fleet events"
expect fleet "policy show" "module fleet.sh fleet enforce status"
expect fleet "policy set advisory" "module fleet.sh fleet enforce set advisory"
expect fleet "" "module fleet.sh fleet"
expect fleet "events" "module fleet.sh fleet events"

test_start "entries_return_the_status_of_what_they_ran"
DISPATCH_RC=4 run "$REPO_ROOT/plugins/fleet/dot-fleet" status
assert_equals "4" "$RC" "fleet"
DISPATCH_RC=4 run "$REPO_ROOT/plugins/secret/dot-secret" list
assert_equals "4" "$RC" "secret"
DISPATCH_RC=4 run "$REPO_ROOT/plugins/attest/dot-attest" verify
assert_equals "4" "$RC" "attest"

# Through bin/dot: fleet has a fallback, secret and security do not.
test_start "fallback_decides_where_other_words_go"
run "$REPO_ROOT/bin/dot" fleet events
assert_equals "module fleet.sh fleet events" "$OUT" "an old fleet word reaches the entry"
run "$REPO_ROOT/bin/dot" fleet
assert_equals "module fleet.sh fleet" "$OUT" "bare fleet runs the entry"
run "$REPO_ROOT/bin/dot" fleet drift history
assert_equals "module fleet.sh fleet drift history" "$OUT" "an object with fallback passes its old words on"
run "$REPO_ROOT/bin/dot" fleet namespace set fm-eng
assert_equals "module fleet.sh fleet namespace set fm-eng" "$OUT" "so does namespace"
run "$REPO_ROOT/bin/dot" fleet log bogus
assert_equals "127" "$RC" "an object without fallback refuses a word that is not its verb"
assert_equals "" "$OUT" "and runs nothing"
run "$REPO_ROOT/bin/dot" secret bogus
assert_equals "127" "$RC" "secret has no fallback: an unknown word exits 127"
assert_equals "" "$OUT" "and runs nothing"
run "$REPO_ROOT/bin/dot" security
assert_equals "0" "$RC" "bare security lists its commands"
assert_equals "" "$OUT" "and runs nothing"
assert_contains "dot security" "$(cat "$WORK/out")" "the listing names the domain"

test_summary
