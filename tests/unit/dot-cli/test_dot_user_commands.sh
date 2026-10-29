#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The user commands from before plugins: for a word the table does not
# know, ~/.config/dotfiles/commands/WORD.sh, then dot-WORD beside bin/dot or
# on PATH. Each is user-writable, so any process running as the user could
# change what `dot WORD` runs; ADR-016 rules that out. They run only with
# DOT_ALLOW_PATH_PLUGINS=1, with a deprecation warning, and otherwise the
# file found is named and the word is unknown (exit 127).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT="$REPO_ROOT/bin/dot"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-user-cmd.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.config/dotfiles/commands" "$WORK/bin" "$WORK/cache"
MARK="$WORK/ran"

# A user command, and a dot-WORD on PATH, each recording that it ran.
printf 'echo "zzuser $*" >>"%s"; exit 7\n' "$MARK" >"$WORK/home/.config/dotfiles/commands/zzuser.sh"
printf '#!/usr/bin/env bash\necho "zzpath $*" >>"%s"\nexit 5\n' "$MARK" >"$WORK/bin/dot-zzpath"
chmod +x "$WORK/bin/dot-zzpath"

# dot_run ARGS...: bin/dot in a sandbox HOME; ERR and RC (what ran is in
# MARK). Extra environment (DOT_ALLOW_PATH_PLUGINS) comes from the caller.
dot_run() {
  : >"$MARK"
  RC=0
  HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" XDG_CACHE_HOME="$WORK/cache" \
    PATH="$WORK/bin:$PATH" NO_COLOR=1 bash "$DOT" "$@" >/dev/null 2>"$WORK/err" || RC=$?
  ERR="$(cat "$WORK/err")"
}

test_start "a_user_command_is_off_by_default"
dot_run zzuser one
assert_equals "127" "$RC" "the word is unknown"
assert_equals "" "$(cat "$MARK")" "and the user command does not run"
assert_contains "not running $WORK/home/.config/dotfiles/commands/zzuser.sh" "$ERR" "the file found is named"
assert_contains "DOT_ALLOW_PATH_PLUGINS=1" "$ERR" "with how to run it"

test_start "a_dot_word_on_path_is_off_by_default"
dot_run zzpath one
assert_equals "127:" "$RC:$(cat "$MARK")" "dot-zzpath on PATH does not run either"
assert_contains "not running $WORK/bin/dot-zzpath" "$ERR" "and is named"

test_start "opted_in_a_user_command_runs_with_a_warning"
DOT_ALLOW_PATH_PLUGINS=1 dot_run zzuser one two
assert_equals "zzuser one two" "$(cat "$MARK")" "it runs, with the words after it"
assert_equals "7" "$RC" "and its exit status is dot's"
assert_contains "running $WORK/home/.config/dotfiles/commands/zzuser.sh" "$ERR" "the user is told what ran"
assert_contains "deprecated" "$ERR" "and that this is going away"

test_start "opted_in_a_dot_word_on_path_runs"
DOT_ALLOW_PATH_PLUGINS=1 dot_run zzpath three
assert_equals "zzpath three" "$(cat "$MARK")" "dot-zzpath runs"
assert_equals "5" "$RC" "and its exit status is dot's"

test_start "an_unknown_word_with_no_command_is_unknown"
DOT_ALLOW_PATH_PLUGINS=1 dot_run zznothing
assert_equals "127" "$RC" "exit 127"
assert_equals "0" "$(grep -c 'running' <<<"$ERR")" "and nothing is said to run"

# The function itself, in a child bash whose $0 is a stand-in bin/dot, for
# the copy beside bin/dot and for words that are not plain names.
user_command() {
  DOT_ALLOW_PATH_PLUGINS=1 HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" PATH="/usr/bin:/bin" \
    bash -c 'source "$1/lib/dot/names.sh"; shift 2; _dot_user_command "$@"; echo "returned"' \
    "$WORK/self/dot" "$REPO_ROOT" _ "$@" 2>/dev/null
}
mkdir -p "$WORK/self"
: >"$WORK/self/dot"
printf '#!/usr/bin/env bash\necho "beside $*"\n' >"$WORK/self/dot-zzbeside"
chmod +x "$WORK/self/dot-zzbeside"
printf 'echo "escaped"\n' >"$WORK/home/.config/dotfiles/zzout.sh"

test_start "opted_in_a_dot_word_beside_bin_dot_runs"
assert_equals "beside x" "$(user_command zzbeside x)" "dot-zzbeside next to bin/dot runs"

test_start "a_word_that_is_not_a_plain_name_runs_nothing"
assert_equals "returned" "$(user_command ../zzout)" "a path does not reach outside the commands directory"
assert_equals "returned" "$(user_command ZZUSER)" "nor does an uppercase word"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
