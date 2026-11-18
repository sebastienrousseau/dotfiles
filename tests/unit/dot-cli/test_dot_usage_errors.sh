#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The CLI's error contract (ADR-020 N10, N14): a usage error (a bad flag, a
# missing argument) exits 64, a word that names no command exits 127 with
# the one message lib/dot/names.sh gives, and both go to stderr only.
# `--help` after an unknown verb is the unknown verb, not the domain's help.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-usage.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
# A stand-in mise: a dot that leaks a word to mise would print this.
printf '#!/bin/sh\necho "mise ERROR no tasks defined" >&2\nexit 1\n' >"$WORK/bin/mise"
chmod +x "$WORK/bin/mise"

# dot ARGS...: run the CLI in a sandboxed HOME; sets RC, OUT and ERR.
dot() {
  RC=0
  HOME="$WORK" XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" \
    PATH="$WORK/bin:$PATH" NO_COLOR=1 TERM=dumb DOT_LOG_DISABLE=1 \
    "$BASH_BIN" "$REPO_ROOT/bin/dot" "$@" >"$WORK/out" 2>"$WORK/err" </dev/null || RC=$?
  OUT="$(cat "$WORK/out")" ERR="$(cat "$WORK/err")"
}

# usage_error ARGS...: `dot ARGS` is a usage error.
usage_error() {
  test_start "usage_error_$(printf '%s_' "$@" | tr -c 'a-z0-9_' '_')"
  dot "$@"
  assert_equals "64" "$RC" "dot $* exits 64"
  assert_equals "" "$OUT" "nothing on stdout"
  assert_contains "dot: " "$ERR" "the error is on stderr"
}

# unknown ARGS...: `dot ARGS` names no command; MSG is the expected message.
unknown() {
  local msg="$1"
  shift
  test_start "unknown_$(printf '%s_' "$@" | tr -c 'a-z0-9_' '_')"
  dot "$@"
  assert_equals "127" "$RC" "dot $* exits 127"
  assert_equals "" "$OUT" "nothing on stdout"
  assert_equals "$msg" "$ERR" "one message, on stderr"
}

# D1: usage errors exit 64.
usage_error help nope
usage_error fleet apply --bogus
usage_error secret show
usage_error fleet apply --agents --cmd true
dot secret show
assert_contains "usage: dot secret show <KEY>" "$ERR" "the usage line follows"

# D7: one message for every spelling that names no command.
unknown "dot: 'dot nope' is not a command; run 'dot help'" nope
unknown "dot: 'dot fleet bogus' is not a command; run 'dot help fleet'" fleet bogus
# D2: an unknown word does not run the whole doctor.
unknown "dot: 'dot doctor nope' is not a command; run 'dot help doctor'" doctor nope
# D3: an unknown verb does not reach mise.
unknown "dot: 'dot tool nope' is not a command; run 'dot help tool'" tool nope
# D8: --help after an unknown verb is the unknown verb.
unknown "dot: 'dot tool nope' is not a command; run 'dot help tool'" tool nope --help
unknown "dot: 'dot theme nope' is not a command; run 'dot help theme'" theme nope --help
# A word that is neither a theme command nor a theme name (the theme
# script needs a dotfiles source to look the name up).
DOTFILES_DIR="$REPO_ROOT" unknown "dot: 'dot theme nope' is not a command; run 'dot help theme'" theme nope
unknown "dot: 'dot doctor nope' is not a command; run 'dot help doctor'" help doctor nope

test_start "help_for_known_spellings_still_exits_0"
dot tool list --help
assert_equals "0" "$RC" "a command's --help exits 0"
assert_contains "dot tool list" "$OUT" "and shows that command"
dot theme set nord --help
assert_equals "0" "$RC" "words after a command are its arguments"
dot doctor perf --help
assert_equals "0" "$RC" "an object's --help exits 0"
dot tool --help
assert_equals "0" "$RC" "a domain's --help exits 0"

# A word the table does not spell but a fallback entry runs (its legacy
# subcommand) keeps the domain's help: every word for an entry with no word
# list (ai takes any word as a prompt), a listed word for one with a list.
# Only an unlisted word after a domain that lists its words is unknown.
legacy_help() {
  local domain="$1"
  shift
  test_start "legacy_help_${domain}_$(printf '%s_' "$@" | tr -c 'a-z0-9_' '_')"
  dot "$domain" "$@"
  assert_equals "0" "$RC" "dot $domain $* exits 0"
  assert_contains "dot $domain" "$OUT" "and shows the domain's help"
  assert_equals "" "$ERR" "with nothing on stderr"
}
legacy_help ai delegate --help
legacy_help ai claude --help
legacy_help ai chat -h
legacy_help fleet enforce --help
legacy_help theme toggle --help
legacy_help system tune --help
test_start "help_for_a_legacy_word_shows_the_domain"
dot help theme toggle
assert_equals "0" "$RC" "dot help theme toggle exits 0"
assert_contains "dot theme" "$OUT" "and shows theme's help"
unknown "dot: 'dot system bogus' is not a command; run 'dot help system'" system bogus --help

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
