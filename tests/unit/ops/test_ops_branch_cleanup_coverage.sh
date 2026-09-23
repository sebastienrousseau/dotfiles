#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Behavioural tests for scripts/ops/branch-cleanup.sh: every precondition
# skip, both deletion criteria (ancestor and merged-PR with SHA guard), the
# dry-run and apply paths, and the FAIL paths for local and remote deletes.
#
# Everything runs against throwaway repositories under a mktemp root with
# local bare "origin" remotes. Do NOT use cov_setup_sandbox here: it
# symlinks $HOME/.dotfiles to the real repo, and this script deletes
# branches. GIT_CEILING_DIRECTORIES stops git discovery at the sandbox.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/branch-cleanup.sh"
REAL_GIT="$(command -v git)"

_tmp="$(mktemp -d -t dotfiles-branch-cleanup.XXXXXX)"
_tmp="$(cd "$_tmp" && pwd -P)"
trap 'rm -rf "$_tmp"' EXIT

export HOME="$_tmp/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$HOME" "$_tmp/bin"
export GIT_CEILING_DIRECTORIES="$_tmp"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$_tmp/gitconfig"
cat >"$GIT_CONFIG_GLOBAL" <<'EOF'
[user]
  email = t@example.invalid
  name = test
[commit]
  gpgsign = false
[tag]
  gpgsign = false
[init]
  defaultBranch = main
[advice]
  detachedHead = false
EOF
unset GIT_DIR GIT_WORK_TREE

# git wrapper: `git remote show` fails in a repo directory named
# "nodefault", so the no-default-branch skip is reachable offline.
cat >"$_tmp/bin/git" <<EOF
#!/bin/sh
if [ "\$1" = remote ] && [ "\$2" = show ] && [ "\${PWD##*/}" = nodefault ]; then
  exit 1
fi
exec "$REAL_GIT" "\$@"
EOF
# gh stub: authenticated; `pr list` prints the pre-rendered TSV table for
# the repo in the current directory (the script passes --jq, so the stub
# returns what jq would have produced).
cat >"$_tmp/bin/gh" <<EOF
#!/bin/sh
case "\$1" in
  auth) exit 0 ;;
  pr) f="$_tmp/pr/\${PWD##*/}.tsv"; [ -f "\$f" ] && cat "\$f"; exit 0 ;;
esac
exit 1
EOF
chmod +x "$_tmp/bin/git" "$_tmp/bin/gh"
export PATH="$_tmp/bin:$PATH"
mkdir -p "$_tmp/pr"

g() { "$REAL_GIT" "$@"; }

# commit <dir> <file> <msg>
commit() {
  echo "$3" >>"$1/$2"
  g -C "$1" add "$2"
  g -C "$1" commit -qm "$3"
}

# new_origin <name> -> bare repo at $_tmp/origins/<name>.git
new_origin() {
  mkdir -p "$_tmp/origins"
  g init -q --bare -b main "$_tmp/origins/$1.git"
}

# Build a fresh root with one repo per scenario. Sets ROOT.
build_root() {
  rm -rf "$_tmp/root" "$_tmp/origins" "$_tmp/wt" "$_tmp/pr"/*
  ROOT="$_tmp/root"
  mkdir -p "$ROOT"

  # --- main: the deletion scenarios -----------------------------------
  new_origin main
  # Refuse deletion of refs/heads/locked so the remote FAIL path fires.
  cat >"$_tmp/origins/main.git/hooks/pre-receive" <<'EOF'
#!/bin/sh
while read -r old new ref; do
  case "$new" in 0000000000000000000000000000000000000000)
    [ "$ref" = refs/heads/locked ] && { echo "locked" >&2; exit 1; } ;;
  esac
done
exit 0
EOF
  chmod +x "$_tmp/origins/main.git/hooks/pre-receive"
  g clone -q "$_tmp/origins/main.git" "$ROOT/main" 2>/dev/null
  local r="$ROOT/main"
  commit "$r" a base
  g -C "$r" push -q origin main
  # ancestor-merged branches (local + remote)
  g -C "$r" branch done
  g -C "$r" branch develop
  g -C "$r" branch locked
  g -C "$r" branch wtbranch
  # squash-merged branch whose tip still equals the PR head
  g -C "$r" checkout -q -b squashed
  commit "$r" s squash-work
  squash_sha="$(g -C "$r" rev-parse HEAD)"
  # branch that moved after its PR merged
  g -C "$r" checkout -q -b moved main
  commit "$r" m moved-1
  moved_pr_sha="$(g -C "$r" rev-parse HEAD)"
  commit "$r" m moved-2
  # plain unmerged branch
  g -C "$r" checkout -q -b wip main
  commit "$r" w wip
  g -C "$r" checkout -q main
  g -C "$r" merge -q --squash squashed >/dev/null
  g -C "$r" commit -qm "squash merge"
  g -C "$r" push -q origin main done develop locked squashed moved wip 2>/dev/null
  g -C "$r" branch -D locked -q
  # wtbranch is checked out elsewhere, so `git branch -D` refuses it.
  g -C "$r" worktree add -q "$_tmp/wt" wtbranch 2>/dev/null
  g -C "$r" fetch -q origin
  printf 'squashed\t%s\t12\nmoved\t%s\t13\nmoved\tdeadbeef\t9\n' \
    "$squash_sha" "$moved_pr_sha" >"$_tmp/pr/main.tsv"

  [[ "${1:-}" == main-only ]] && return 0

  # --- dirty worktree -------------------------------------------------
  g init -q "$ROOT/dirty"
  commit "$ROOT/dirty" a base
  echo edit >>"$ROOT/dirty/a"

  # --- detached HEAD --------------------------------------------------
  g init -q "$ROOT/detached"
  commit "$ROOT/detached" a base
  g -C "$ROOT/detached" checkout -q --detach HEAD

  # --- fetch fails (origin path missing) --------------------------------
  g init -q "$ROOT/nofetch"
  commit "$ROOT/nofetch" a base
  g -C "$ROOT/nofetch" remote add origin "$_tmp/origins/missing.git"

  # --- no origin/HEAD, and `remote show` fails --------------------------
  new_origin nodefault
  g init -q "$ROOT/nodefault"
  commit "$ROOT/nodefault" a base
  g -C "$ROOT/nodefault" remote add origin "$_tmp/origins/nodefault.git"
  g -C "$ROOT/nodefault" config remote.origin.followRemoteHEAD never
  g -C "$ROOT/nodefault" push -q origin main

  # --- no origin/HEAD, default recovered via `remote show` -------------
  new_origin fallback
  g init -q "$ROOT/fallback"
  commit "$ROOT/fallback" a base
  g -C "$ROOT/fallback" remote add origin "$_tmp/origins/fallback.git"
  g -C "$ROOT/fallback" config remote.origin.followRemoteHEAD never
  g -C "$ROOT/fallback" push -q origin main

  # --- checked out on a non-default branch -----------------------------
  new_origin offdefault
  g clone -q "$_tmp/origins/offdefault.git" "$ROOT/offdefault" 2>/dev/null
  commit "$ROOT/offdefault" a base
  g -C "$ROOT/offdefault" push -q origin main
  g -C "$ROOT/offdefault" remote set-head origin main
  g -C "$ROOT/offdefault" checkout -q -b topic

  # --- a .git directory that is not a repository -----------------------
  mkdir -p "$ROOT/broken/.git"
}

run_script() { # env assignments..., output to $_tmp/out
  env "$@" BRANCH_CLEANUP_ROOT="$ROOT" bash "$TEST_SCRIPT" >"$_tmp/out" 2>&1
  rc=$?
  out="$(cat "$_tmp/out")"
}

manifest_row() { # <mode> <repo> <scope> <branch> -> status + reason
  local m
  m="$(find "$ROOT/.branch-cleanup" -name "*-$1.manifest.tsv" | sort | tail -1)"
  awk -F'\t' -v r="$2" -v s="$3" -v b="$4" \
    '$2 == r && $3 == s && $4 == b { print $1 " " $6 }' "$m"
}

# Library mode: the _apply companion sources this file for the fixture and
# stops here. The suite is split in two so each half stays well inside the
# coverage runner's per-test timeout on a loaded host.
[[ "${BRANCH_CLEANUP_COV_LIB:-0}" == 1 ]] && return 0

# ── Dry run with gh: every skip and every verdict ───────────────────────
test_start "branch_cleanup_dry_run_all_scenarios"
build_root
run_script
assert_equals 0 "$rc" "dry run exits 0"
assert_contains "gh=1" "$out" "gh stub is detected as authenticated"
assert_contains "SKIP dirty :: dirty worktree" "$out" "dirty repo skipped"
assert_contains "SKIP detached :: detached HEAD" "$out" "detached repo skipped"
assert_contains "SKIP nofetch :: fetch failed" "$out" "unfetchable repo skipped"
assert_contains "SKIP nodefault :: no default branch" "$out" \
  "repo without a default branch skipped"
assert_contains "SKIP offdefault :: on 'topic', not default 'main'" "$out" \
  "repo off its default branch skipped"
# Regression: a repo without origin/HEAD used to abort the whole run
# (symbolic-ref | sed failed under pipefail + errexit), so the remote-show
# fallback was unreachable and every later repo went unprocessed.
assert_contains "=== fallback (default=main)" "$out" \
  "default branch recovered from remote show"
assert_contains "(merged PRs with head refs: 2)" "$out" \
  "PR table keeps only the newest row per head ref"
assert_equals "DRY ancestor-of-main" "$(manifest_row dry main local done)" \
  "ancestor local branch is a dry-run candidate"
assert_equals "DRY pr#12-merged" "$(manifest_row dry main local squashed)" \
  "squash-merged branch matched by PR head SHA"
assert_equals "LEFT moved-since-pr#13" "$(manifest_row dry main local moved)" \
  "branch moved since its PR is left"
assert_equals "LEFT not-merged" "$(manifest_row dry main local wip)" \
  "unmerged branch is left"
assert_equals "KEEP protected" "$(manifest_row dry main local develop)" \
  "protected local branch kept"
assert_equals "KEEP protected" "$(manifest_row dry main origin develop)" \
  "protected remote branch kept"
assert_equals "DRY pr#12-merged" "$(manifest_row dry main origin squashed)" \
  "remote squash-merged branch is a candidate"
assert_equals "LEFT not-merged" "$(manifest_row dry main origin wip)" \
  "remote unmerged branch is left"
assert_true "g -C '$ROOT/main' show-ref --verify --quiet refs/heads/done" \
  "dry run deletes nothing locally"
assert_true "g --git-dir='$_tmp/origins/main.git' show-ref --verify --quiet refs/heads/done" \
  "dry run deletes nothing on origin"
assert_false "grep -q broken '$_tmp/out'" "non-repository .git dir is ignored"
assert_false "[[ -e '$ROOT/.branch-cleanup/'*-restore.sh ]]" \
  "dry run writes no restore script"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
