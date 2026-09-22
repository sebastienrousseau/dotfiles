#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Behavioural tests for `rollback.sh git-reset`: it must never discard
# uncommitted edits or commits made since the last tag.
#
# Runs against a throwaway git repository at $HOME/.dotfiles. Do NOT use
# cov_setup_sandbox here: it symlinks $HOME/.dotfiles to the real repo,
# and this script runs `git reset --hard` there.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ROLLBACK_FILE="$REPO_ROOT/scripts/ops/rollback.sh"

_tmp=$(mktemp -d -t dotfiles-rollback.XXXXXX)
trap 'rm -rf "$_tmp"' EXIT

# Build a fresh sandbox: tagged commit, one local commit ahead, optional
# dirty edit. Echoes nothing; sets globals used by the cases below.
_setup() {
  rm -rf "$_tmp/home" "$_tmp/bin"
  export HOME="$_tmp/home"
  export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state"
  export XDG_RUNTIME_DIR="$_tmp/run"
  mkdir -p "$HOME/.dotfiles" "$_tmp/bin" "$XDG_RUNTIME_DIR"
  # Stub chezmoi so the re-apply step never touches a real home.
  printf '#!/bin/sh\nexit 0\n' >"$_tmp/bin/chezmoi"
  chmod +x "$_tmp/bin/chezmoi"
  export PATH="$_tmp/bin:$PATH"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  (
    cd "$HOME/.dotfiles" || exit 1
    git init -q -b main
    git config user.email t@example.invalid
    git config user.name test
    git config commit.gpgsign false
    git config tag.gpgsign false
    echo base >tracked.txt
    git add tracked.txt
    git commit -qm base
    git tag v1
    echo local >>tracked.txt
    git commit -qam "local work"
  )
  local_head=$(git -C "$HOME/.dotfiles" rev-parse HEAD)
}

_run() { # stdin answers, then args
  local answers="$1"
  shift
  printf '%b' "$answers" | bash "$ROLLBACK_FILE" git-reset "$@" >"$_tmp/out" 2>&1
}

# ── Declining the stash must abort, not reset ───────────────────────
test_start "git_reset_decline_stash_keeps_dirty_tree"
_setup
echo "uncommitted" >"$HOME/.dotfiles/dirty.txt"
echo "edited" >>"$HOME/.dotfiles/tracked.txt"
_run 'y\nn\n'
rc=$?
assert_not_equals "0" "$rc" "declining the stash exits non-zero"
test_start "git_reset_decline_stash_head_unchanged"
assert_equals "$local_head" "$(git -C "$HOME/.dotfiles" rev-parse HEAD)" "HEAD not moved"
test_start "git_reset_decline_stash_edits_kept"
assert_file_contains "$HOME/.dotfiles/tracked.txt" "edited" "tracked edit preserved"
test_start "git_reset_decline_stash_untracked_kept"
assert_file_exists "$HOME/.dotfiles/dirty.txt" "untracked file preserved"

# ── A prompt timeout / closed stdin counts as a decline ─────────────
test_start "git_reset_no_answer_keeps_dirty_tree"
_setup
echo "edited" >>"$HOME/.dotfiles/tracked.txt"
_run 'y\n'
rc=$?
assert_not_equals "0" "$rc" "no answer to the stash prompt exits non-zero"
test_start "git_reset_no_answer_edits_kept"
assert_file_contains "$HOME/.dotfiles/tracked.txt" "edited" "tracked edit preserved"

# ── Accepting the stash keeps edits recoverable ─────────────────────
test_start "git_reset_accept_stash_records_edits"
_setup
echo "edited" >>"$HOME/.dotfiles/tracked.txt"
echo "uncommitted" >"$HOME/.dotfiles/dirty.txt"
_run 'y\ny\n'
rc=$?
assert_equals "0" "$rc" "reset succeeds after stashing"
test_start "git_reset_accept_stash_single_stash"
stash_count=$(git -C "$HOME/.dotfiles" stash list | grep -c 'rollback' || true)
assert_equals "1" "$stash_count" "one rollback stash recorded"
test_start "git_reset_accept_stash_includes_untracked"
untracked=$(git -C "$HOME/.dotfiles" show --name-only --format= 'stash@{0}^3' 2>/dev/null || true)
assert_equals "dirty.txt" "$untracked" "untracked file captured in the stash"

# ── Local commits since the tag stay reachable on a named ref ───────
test_start "git_reset_preserves_local_commits"
_setup
_run 'y\n'
rc=$?
assert_equals "0" "$rc" "reset on a clean tree succeeds"
test_start "git_reset_moves_to_tag"
assert_equals "$(git -C "$HOME/.dotfiles" rev-parse 'v1^{commit}')" \
  "$(git -C "$HOME/.dotfiles" rev-parse HEAD)" "HEAD reset to last tag"
test_start "git_reset_backup_ref_points_at_old_head"
backup_ref=$(git -C "$HOME/.dotfiles" for-each-ref --format='%(objectname)' 'refs/heads/rollback-backup/*')
assert_equals "$local_head" "$backup_ref" "rollback-backup branch keeps the pre-reset commit"

# ── --force stashes (with untracked) instead of discarding ──────────
test_start "git_reset_force_stashes_untracked"
_setup
echo "uncommitted" >"$HOME/.dotfiles/dirty.txt"
_run '' --force
rc=$?
assert_equals "0" "$rc" "forced reset succeeds"
test_start "git_reset_force_untracked_in_stash"
untracked=$(git -C "$HOME/.dotfiles" show --name-only --format= 'stash@{0}^3' 2>/dev/null || true)
assert_equals "dirty.txt" "$untracked" "forced reset stashes untracked files"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
