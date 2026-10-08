#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# core.hooksPath points every repository at the global hooks directory,
# which hides each repository's own .git/hooks (pre-commit, gitleaks,
# conventional commits). The global hooks must chain to them: a rejecting
# repository hook blocks the commit, a passing one lets the global
# commit-msg add its signature, and a hooks dir that is the global one
# must not recurse.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SRC_HOOKS="$REPO_ROOT/defaults/dot_config/git/hooks"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/git-hook-chain.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Deploy the hooks the way chezmoi does: strip executable_, set +x.
HOOKS="$WORK/hooks"
mkdir -p "$HOOKS"
for src in "$SRC_HOOKS"/*; do
  dest="$HOOKS/$(basename "$src")"
  dest="${dest/\/executable_//}"
  cp "$src" "$dest"
  chmod +x "$dest"
done

mkdir -p "$WORK/home/.euxis/data/config/branding"
printf 'SIG LINE ONE\nSIG LINE TWO\n' >"$WORK/home/.euxis/data/config/branding/signature.txt"

# run_in <dir> <cmd...>: a clean environment (no AI-session variables, no
# user or system git config) rooted in <dir>.
run_in() {
  local dir="$1"
  shift
  (cd "$dir" && env -i HOME="$WORK/home" PATH="$PATH" XDG_CONFIG_HOME="$WORK/xdg" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$WORK" \
    GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.com \
    GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.com "$@")
}

# new_repo <name>: a repository whose hooksPath is the deployed global dir.
new_repo() {
  local repo="$WORK/$1"
  mkdir -p "$repo"
  run_in "$repo" git init -q
  run_in "$repo" git config commit.gpgsign false
  run_in "$repo" git config core.hooksPath "$HOOKS"
  printf '%s\n' "$1" >"$repo/file"
  run_in "$repo" git add file
  printf '%s\n' "$repo"
}

# local_hook <repo> <name> <exit-code>: a repository hook that logs its
# name and arguments (and stdin, when it is not a terminal), then exits
# with <exit-code>.
local_hook() {
  mkdir -p "$1/.git/hooks"
  cat >"$1/.git/hooks/$2" <<HOOK
#!/usr/bin/env bash
printf '%s %s\n' "$2" "\$*" >>"$1/hook.log"
if [[ "\${CHAIN_TEST_STDIN:-}" == 1 ]]; then cat >>"$1/hook.log"; fi
exit $3
HOOK
  chmod +x "$1/.git/hooks/$2"
}

commit() { run_in "$1" timeout 30 git commit -q -m 'feat: thing' >/dev/null 2>&1; }
last_msg() { run_in "$1" git log -1 --format=%B; }

test_start "rejecting_repo_pre_commit_blocks_the_commit"
repo="$(new_repo reject)"
local_hook "$repo" pre-commit 1
commit "$repo"
assert_equals 1 "$?" "git commit fails when the repository's pre-commit exits 1"
assert_false "run_in '$repo' git rev-parse -q --verify HEAD >/dev/null" "no commit was made"

test_start "passing_repo_pre_commit_runs_and_signature_is_added"
repo="$(new_repo pass)"
local_hook "$repo" pre-commit 0
commit "$repo"
assert_equals 0 "$?" "git commit succeeds when the repository's pre-commit exits 0"
assert_contains 'pre-commit' "$(cat "$repo/hook.log" 2>/dev/null)" "the repository's pre-commit ran"
assert_contains 'SIG LINE ONE' "$(last_msg "$repo")" "the global commit-msg still adds the signature"

test_start "rejecting_repo_commit_msg_blocks_before_branding"
repo="$(new_repo msgreject)"
local_hook "$repo" commit-msg 1
commit "$repo"
assert_equals 1 "$?" "git commit fails when the repository's commit-msg exits 1"
assert_contains '.git/COMMIT_EDITMSG' "$(cat "$repo/hook.log" 2>/dev/null)" "the repository's commit-msg got the message file"
assert_false "grep -q 'SIG LINE ONE' '$repo/.git/COMMIT_EDITMSG'" "no signature added after a rejection"

test_start "passing_repo_commit_msg_then_signature"
repo="$(new_repo msgpass)"
local_hook "$repo" commit-msg 0
commit "$repo"
assert_equals 0 "$?" "git commit succeeds when the repository's commit-msg exits 0"
assert_contains 'commit-msg' "$(cat "$repo/hook.log" 2>/dev/null)" "the repository's commit-msg ran"
assert_contains 'SIG LINE ONE' "$(last_msg "$repo")" "signature added after the repository hook passed"

test_start "non_executable_repo_hook_is_ignored"
repo="$(new_repo noexec)"
local_hook "$repo" pre-commit 1
chmod -x "$repo/.git/hooks/pre-commit"
commit "$repo"
assert_equals 0 "$?" "a non-executable repository hook does not block, as with git itself"

test_start "repo_without_local_hooks_commits_normally"
repo="$(new_repo nohooks)"
rm -rf "$repo/.git/hooks"
commit "$repo"
assert_equals 0 "$?" "git commit succeeds with no .git/hooks at all"
assert_contains 'SIG LINE ONE' "$(last_msg "$repo")" "signature added"

test_start "hooks_dir_that_is_the_global_dir_does_not_loop"
repo="$(new_repo loop)"
rm -rf "$repo/.git/hooks"
ln -s "$HOOKS" "$repo/.git/hooks"
commit "$repo"
assert_equals 0 "$?" "git commit finishes (no recursion, no timeout)"
assert_equals 1 "$(last_msg "$repo" | grep -c 'SIG LINE ONE')" "signature added exactly once"

test_start "wrappers_chain_their_own_name_args_and_stdin"
repo="$(new_repo wrappers)"
for name in pre-commit prepare-commit-msg pre-push post-checkout post-merge pre-rebase pre-merge-commit post-commit post-rewrite; do
  local_hook "$repo" "$name" 7
  : >"$repo/hook.log"
  printf 'refs/heads/main abc\n' |
    run_in "$repo" env CHAIN_TEST_STDIN=1 "$HOOKS/$name" arg1 arg2 >/dev/null 2>&1
  assert_equals 7 "$?" "$name passes the repository hook's exit status through"
  assert_equals "$name arg1 arg2"$'\n'"refs/heads/main abc" "$(cat "$repo/hook.log")" "$name forwards its arguments and stdin"
done

test_start "chain_outside_a_repository_is_a_no_op"
mkdir -p "$WORK/plain"
run_in "$WORK/plain" "$HOOKS/_chain" pre-commit >/dev/null 2>&1
assert_equals 0 "$?" "_chain exits 0 when not inside a repository"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
