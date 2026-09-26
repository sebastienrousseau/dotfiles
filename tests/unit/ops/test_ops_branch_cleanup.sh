#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/branch-cleanup.sh"

# The fixture needs the real git: cov_setup_sandbox puts a stub git first
# on PATH for the coverage exercise at the end.
REAL_GIT="$(command -v git)"
REAL_GIT_DIR="$(dirname "$REAL_GIT")"
trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "branch_cleanup_exists"
assert_file_exists "$TEST_SCRIPT" "branch-cleanup.sh should exist"

# ── A fixture world ────────────────────────────────────────────────────────
# A bare origin and a clean clone on main, with one branch per case the
# script distinguishes. gh is a stub: `auth status` succeeds and
# `pr list` returns the merged-PR table (name, headRefOid, number).
W="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/branch-cleanup.XXXXXX")" && pwd)"
trap 'rm -rf "$W"; cov_teardown_sandbox' EXIT
g() { "$REAL_GIT" -c user.email=t@example.com -c user.name=t -c commit.gpgsign=false "$@"; }
(
  set -e
  "$REAL_GIT" init -q --bare -b main "$W/origin.git"
  g clone -q "$W/origin.git" "$W/root/repo" 2>/dev/null
  cd "$W/root/repo"
  echo a >a && g add a && g commit -qm a
  for b in gh-pages develop trunk master; do g branch "$b"; done
  g checkout -qb feature/done && echo b >b && g add b && g commit -qm b
  g checkout -q main && g merge -q --no-ff feature/done -m merge-done
  g checkout -qb pr/landed main && echo c >c && g add c && g commit -qm c
  g checkout -qb pr/moved main && echo d >d && g add d && g commit -qm d
  g rev-parse HEAD >"$W/moved-pr-sha"
  echo d2 >>d && g commit -qam d2
  g checkout -qb wip main && echo e >e && g add e && g commit -qm e
  g checkout -qb feature/late main && echo f >f && g add f && g commit -qm f
  g checkout -q main
  g push -q origin --all
  g remote set-head origin main
  # Another clone merges feature/late into origin/main; this clone has not
  # fetched since, so its origin/main does not contain feature/late yet.
  g clone -q "$W/origin.git" "$W/other" 2>/dev/null
  cd "$W/other" && g merge -q --no-ff origin/feature/late -m merge-late && g push -q origin main
) >/dev/null 2>&1
printf 'pr/landed\t%s\t1\npr/moved\t%s\t2\n' \
  "$(g -C "$W/root/repo" rev-parse pr/landed)" "$(cat "$W/moved-pr-sha")" >"$W/prs.tsv"
mkdir -p "$W/bin"
printf '#!/bin/sh\ncase "$1 $2" in "auth status") exit 0 ;; "pr list") cat "%s" ;; esac\n' "$W/prs.tsv" >"$W/bin/gh"
chmod +x "$W/bin/gh"

# cleanup [APPLY]: run the script on the fixture root.
cleanup() {
  env PATH="$W/bin:$REAL_GIT_DIR:$PATH" BRANCH_CLEANUP_ROOT="$W/root" APPLY="${1:-0}" bash "$TEST_SCRIPT" >"$W/out" 2>&1 || true
}
# has_ref <ref>: the clone (local) or origin.git (remote) has it.
local_has() { g -C "$W/root/repo" show-ref --verify --quiet "refs/heads/$1"; }
remote_has() { g -C "$W/origin.git" show-ref --verify --quiet "refs/heads/$1"; }
# row <status> <scope> <branch>: the newest manifest has that row.
row() { awk -F'\t' -v s="$1" -v c="$2" -v b="$3" '$1==s && $3==c && $4==b {f=1} END{exit !f}' "$(ls -t "$W/root/.branch-cleanup/"*.manifest.tsv | head -1)"; }

cleanup 0

test_start "branch_cleanup_dry_run_deletes_nothing"
assert_true 'local_has feature/done && remote_has feature/done && local_has pr/landed && remote_has feature/late' \
  "a dry run reports candidates but deletes nothing (APPLY defaults to 0)"

test_start "branch_cleanup_dry_run_reports_candidates"
assert_true 'row DRY local feature/done && row DRY origin feature/done && row DRY local pr/landed' \
  "merged branches are reported as DRY candidates"

test_start "branch_cleanup_protects_default_branches"
assert_true 'row KEEP local gh-pages && row KEEP local develop && row KEEP local trunk && row KEEP origin master' \
  "gh-pages, develop, trunk and master are kept as protected"

test_start "branch_cleanup_requires_fetch_before_judging"
assert_true 'row DRY local feature/late' \
  "a branch merged upstream after the clone last fetched is a candidate (the script fetches first)"

test_start "branch_cleanup_matches_pr_by_sha_not_name"
assert_true 'row DRY local pr/landed && row LEFT local pr/moved && grep -q "moved-since-pr#2" "$(ls -t "$W/root/.branch-cleanup/"*.manifest.tsv | head -1)"' \
  "a merged PR's branch is a candidate only while its tip equals the PR head; a moved one is left"

test_start "branch_cleanup_leaves_unmerged"
assert_true 'row LEFT local wip' "an unmerged branch with no PR is left"

test_start "branch_cleanup_manifest_sorted_by_identity"
assert_true 'sort -c -t"$(printf "\t")" -k2,2 -k3,3 -k4,4 "$(ls -t "$W/root/.branch-cleanup/"*.manifest.tsv | head -1)"' \
  "manifest rows are sorted by repo, scope and branch, not status"

sleep 1 # manifests are timestamped to the second
cleanup 1

test_start "branch_cleanup_apply_deletes_candidates"
assert_true '! local_has feature/done && ! remote_has feature/done && ! local_has pr/landed && ! remote_has pr/landed && ! local_has feature/late' \
  "APPLY=1 deletes the landed branches locally and on origin"

test_start "branch_cleanup_apply_keeps_the_rest"
assert_true 'local_has gh-pages && remote_has develop && local_has pr/moved && remote_has pr/moved && local_has wip' \
  "APPLY=1 keeps protected, moved and unmerged branches"

test_start "branch_cleanup_restore_brings_branches_back"
done_sha="$(awk -F'\t' '$3=="local" && $4=="feature/done" {print $5}' "$(ls -t "$W/root/.branch-cleanup/"*apply.manifest.tsv | head -1)")"
env PATH="$REAL_GIT_DIR:$PATH" bash "$(ls -t "$W/root/.branch-cleanup/"*-restore.sh | head -1)" >/dev/null 2>&1 || true
assert_true 'local_has feature/done && remote_has feature/done && remote_has pr/landed && [[ "$(g -C "$W/root/repo" rev-parse feature/done)" == "$done_sha" ]]' \
  "the restore script re-creates deleted branches at their old tips, locally and on origin"

test_start "branch_cleanup_missing_root_is_not_an_error"
# Exercised in CI where the default root does not exist: it must exit
# cleanly rather than fail the suite or create directories.
out="$(BRANCH_CLEANUP_ROOT="$PWD/definitely-not-here" bash "$TEST_SCRIPT" 2>&1 || true)"
assert_contains "root not found" "$out" "should report a missing root"
if [[ ! -d "$PWD/definitely-not-here" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: did not create the missing root"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: created the missing root"
fi

# Exercise the script under sandbox for line coverage (#883).
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
