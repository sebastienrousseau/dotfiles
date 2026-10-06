#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The commit-msg hook's branding signature must not separate a trailer
# block (Signed-off-by, Assisted-by) from the end of the message: git reads
# trailers from the last paragraph only, so a signature appended after them
# hid the sign-off from DCO and from %(trailers:...).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HOOK="${COMMIT_MSG_HOOK:-$REPO_ROOT/defaults/dot_config/git/hooks/executable_commit-msg}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/commit-msg-sig.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.euxis/data/config/branding"
printf 'SIG LINE ONE\nSIG LINE TWO\n' >"$WORK/home/.euxis/data/config/branding/signature.txt"

# hook <message...>: run the hook on that message in a clean environment (no
# AI-session variables, so no Assisted-by injection) and print the result.
hook() {
  printf '%b' "$1" >"$WORK/msg"
  env -i HOME="$WORK/home" PATH="$PATH" bash "$HOOK" "$WORK/msg" >/dev/null 2>&1 || return $?
  cat "$WORK/msg"
}
line_of() { grep -n -F -- "$1" | head -1 | cut -d: -f1; }

test_start "signature_goes_before_a_trailing_trailer_block"
got="$(hook 'feat: thing\n\nWhy the thing.\n\nAssisted-by: Tool:model\nSigned-off-by: Dev <dev@example.com>\n')"
sig="$(printf '%s\n' "$got" | line_of 'SIG LINE ONE')"
sob="$(printf '%s\n' "$got" | line_of 'Signed-off-by:')"
assert_true "[[ $sig -lt $sob ]]" "signature (line $sig) precedes the trailers (line $sob)"
parsed="$(printf '%s\n' "$got" | git interpret-trailers --parse)"
assert_contains 'Assisted-by: Tool:model' "$parsed" "git still sees Assisted-by as a trailer"
assert_contains 'Signed-off-by: Dev <dev@example.com>' "$parsed" "git still sees Signed-off-by as a trailer"

test_start "signature_is_appended_when_there_are_no_trailers"
got="$(hook 'fix: thing\n\nBody only.\n')"
assert_equals 'SIG LINE TWO' "$(printf '%s\n' "$got" | sed '/^$/d' | tail -1)" "signature ends the message"
assert_equals '' "$(printf '%s\n' "$got" | git interpret-trailers --parse)" "no trailers invented"

test_start "signature_keeps_editor_comment_lines_after_everything"
got="$(hook 'feat: thing\n\nBody.\n\nSigned-off-by: Dev <dev@example.com>\n\n# Please enter the commit message\n# Lines starting with # are ignored\n')"
sig="$(printf '%s\n' "$got" | line_of 'SIG LINE ONE')"
sob="$(printf '%s\n' "$got" | line_of 'Signed-off-by:')"
cmt="$(printf '%s\n' "$got" | line_of '# Please enter')"
assert_true "[[ $sig -lt $sob && $sob -lt $cmt ]]" "order is signature ($sig), trailers ($sob), comments ($cmt)"
assert_equals 2 "$(printf '%s\n' "$got" | grep -c '^#')" "both comment lines survive"

test_start "signature_is_added_once"
first="$(hook 'feat: thing\n\nBody.\n\nSigned-off-by: Dev <dev@example.com>\n')"
printf '%s\n' "$first" >"$WORK/msg"
env -i HOME="$WORK/home" PATH="$PATH" bash "$HOOK" "$WORK/msg" >/dev/null 2>&1
assert_equals 1 "$(grep -c 'SIG LINE ONE' "$WORK/msg")" "a second run does not duplicate the signature"

test_start "merge_commits_are_left_alone"
got="$(hook "Merge branch 'topic'\n")"
assert_equals "Merge branch 'topic'" "$got" "no signature on a merge message"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
