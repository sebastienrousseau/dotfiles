#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031,SC2154
# Behavioural tests for scripts/ops/branch-cleanup.sh, apply half: ONLY and
# NO_GH filtering, real deletion, both FAIL paths, the restore script and
# the reconcile hint. Reuses the throwaway-repo fixture from
# test_ops_branch_cleanup_coverage.sh (library mode); nothing here touches
# a real repository.
set -uo pipefail

BRANCH_CLEANUP_COV_LIB=1
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_ops_branch_cleanup_coverage.sh"

build_root main-only
# A second clean repo, so ONLY has something to filter out.
g init -q "$ROOT/other"
commit "$ROOT/other" a base

# ── ONLY filter and NO_GH (dry) ─────────────────────────────────────────
test_start "branch_cleanup_only_and_no_gh"
run_script ONLY=main NO_GH=1
assert_equals 0 "$rc" "ONLY run exits 0"
assert_contains "only=main gh=0" "$out" "header reflects ONLY and NO_GH"
assert_false "grep -q '=== other' '$_tmp/out'" "other repos are not visited"
assert_false "grep -q 'merged PRs' '$_tmp/out'" "no PR lookup without gh"
assert_equals "LEFT not-merged" "$(manifest_row dry main local squashed)" \
  "without gh a squash-merged branch is not provably merged"
assert_equals "DRY ancestor-of-main" "$(manifest_row dry main local done)" \
  "ancestor criterion works offline"

# ── Apply: deletes, FAIL paths, restore script, reconcile hint ──────────
test_start "branch_cleanup_apply_deletes_and_records"
run_script ONLY=main APPLY=1
assert_equals 0 "$rc" "apply exits 0"
assert_contains "del   local  done (ancestor-of-main)" "$out" \
  "ancestor local branch deleted"
assert_contains "del   local  squashed (pr#12-merged)" "$out" \
  "squash-merged local branch deleted"
assert_contains "FAIL  local  wtbranch" "$out" \
  "branch checked out in another worktree reported as FAIL"
assert_contains "del   origin done (ancestor-of-main)" "$out" \
  "ancestor remote branch deleted"
assert_contains "FAIL  origin locked (push --delete refused; protected?)" "$out" \
  "refused remote delete reported as FAIL"
assert_contains "failed=2" "$out" "summary counts both failures"
assert_contains "Restore:" "$out" "restore path printed"
assert_contains "Reconcile against previous run:" "$out" \
  "previous dry-run manifest offered for reconciliation"
assert_false "g -C '$ROOT/main' show-ref --verify --quiet refs/heads/done" \
  "local branch really deleted"
assert_false "g --git-dir='$_tmp/origins/main.git' show-ref --verify --quiet refs/heads/squashed" \
  "remote branch really deleted"
assert_true "g -C '$ROOT/main' show-ref --verify --quiet refs/heads/moved" \
  "moved branch survives apply"
assert_true "g --git-dir='$_tmp/origins/main.git' show-ref --verify --quiet refs/heads/develop" \
  "protected remote branch survives apply"
restore="$(find "$ROOT/.branch-cleanup" -name '*-restore.sh' | head -1)"
assert_file_contains "$restore" "git branch -f \"done\" $(g --git-dir="$_tmp/origins/main.git" rev-parse main~1)" \
  "restore script re-points the deleted local branch"
assert_file_contains "$restore" "git push origin $squash_sha:refs/heads/\"squashed\"" \
  "restore script re-pushes the deleted remote branch"

# Running the restore script brings the deleted branches back.
test_start "branch_cleanup_restore_script_round_trips"
bash "$restore" >/dev/null 2>&1
assert_true "g -C '$ROOT/main' show-ref --verify --quiet refs/heads/done" \
  "restore recreates the local branch"
assert_true "g --git-dir='$_tmp/origins/main.git' show-ref --verify --quiet refs/heads/squashed" \
  "restore re-pushes the remote branch"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
