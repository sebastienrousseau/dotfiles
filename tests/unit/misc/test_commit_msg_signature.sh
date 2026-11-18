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
mkdir -p "$WORK/home/.euxis/data/config/branding" "$WORK/bin"
printf 'SIG LINE ONE\nSIG LINE TWO\n' >"$WORK/home/.euxis/data/config/branding/signature.txt"
printf '#!/bin/sh\nexit 1\n' >"$WORK/bin/pgrep"
chmod +x "$WORK/bin/pgrep"

# repo_with <url...>: a fresh repository with one remote per URL; prints it.
repo_with() {
  local dir n=0 url
  dir="$(mktemp -d "$WORK/repo.XXXXXX")"
  git -C "$dir" init -q
  for url in "$@"; do
    n=$((n + 1))
    git -C "$dir" remote add "r$n" "$url"
  done
  printf '%s\n' "$dir"
}
OWNED="$(repo_with git@github.com:sebastienrousseau/dotfiles.git)"
REPO="$OWNED"

# hook <message...>: run the hook on that message in $REPO in a clean
# environment (no AI-session variables, so no Assisted-by injection) and
# print the result.
hook() {
  printf '%b' "$1" >"$WORK/msg"
  (cd "$REPO" && env -i HOME="$WORK/home" PATH="$WORK/bin:$PATH" GIT_CONFIG_NOSYSTEM=1 \
    TMPDIR="$WORK/tmp" bash "$HOOK" "$WORK/msg") >/dev/null 2>&1 || return $?
  cat "$WORK/msg"
}
mkdir -p "$WORK/tmp"
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
assert_equals '# Lines starting with # are ignored' "$(printf '%s\n' "$got" | sed -n "$((cmt + 1))p")" "the comment block stays contiguous"

test_start "signature_is_added_once"
first="$(hook 'feat: thing\n\nBody.\n\nSigned-off-by: Dev <dev@example.com>\n')"
printf '%s\n' "$first" >"$WORK/msg"
(cd "$REPO" && env -i HOME="$WORK/home" PATH="$WORK/bin:$PATH" bash "$HOOK" "$WORK/msg") >/dev/null 2>&1
assert_equals 1 "$(grep -c 'SIG LINE ONE' "$WORK/msg")" "a second run does not duplicate the signature"

test_start "merge_commits_are_left_alone"
got="$(hook "Merge branch 'topic'\n")"
assert_equals "Merge branch 'topic'" "$got" "no signature on a merge message"

# The signature is personal branding: a commit to another owner's project,
# to a fork that also tracks upstream, or to a repository with no remote
# gets none.
test_start "signature_is_added_in_an_owned_repository"
REPO="$(repo_with https://github.com/SebastienRousseau/other-project)"
assert_contains 'SIG LINE ONE' "$(hook 'fix: thing\n')" "an https remote of the owner (any case) counts as owned"

test_start "signature_skipped_in_a_third_party_repository"
REPO="$(repo_with git@github.com:someone-else/project.git)"
assert_equals 'fix: thing' "$(hook 'fix: thing\n')" "no signature when the remote belongs to someone else"

test_start "signature_skipped_in_a_fork_with_an_upstream_remote"
REPO="$(repo_with git@github.com:sebastienrousseau/project.git https://github.com/upstream-org/project.git)"
assert_equals 'fix: thing' "$(hook 'fix: thing\n')" "no signature when any remote is not the owner's"

test_start "signature_skipped_without_a_remote"
REPO="$(repo_with)"
assert_equals 'fix: thing' "$(hook 'fix: thing\n')" "no signature in a repository with no remote"

test_start "signature_owner_follows_git_config"
REPO="$(repo_with git@github.com:someone-else/project.git)"
git -C "$REPO" config euxis.brandingOwner someone-else
assert_contains 'SIG LINE ONE' "$(hook 'fix: thing\n')" "euxis.brandingOwner names the owner"

# The hook's temporary file goes even when writing the message back fails.
# A mktemp stub puts it where the test can look (BSD mktemp ignores TMPDIR).
test_start "temporary_file_removed_when_the_hook_fails"
REPO="$OWNED"
cat >"$WORK/bin/mktemp" <<'STUB'
#!/bin/sh
f="$TMPDIR/hook.$$"
: >"$f" && printf '%s\n' "$f"
STUB
chmod +x "$WORK/bin/mktemp"
printf 'fix: thing\n' >"$WORK/msg"
chmod 444 "$WORK/msg"
rm -rf "$WORK/tmp" && mkdir -p "$WORK/tmp"
rc=0
(cd "$REPO" && env -i HOME="$WORK/home" PATH="$WORK/bin:$PATH" TMPDIR="$WORK/tmp" \
  bash "$HOOK" "$WORK/msg") >/dev/null 2>&1 || rc=$?
chmod 644 "$WORK/msg"
assert_not_equals 0 "$rc" "the hook fails when the message file is read-only"
assert_equals '' "$(ls -A "$WORK/tmp")" "and leaves no temporary file behind"
rm -f "$WORK/bin/mktemp"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
