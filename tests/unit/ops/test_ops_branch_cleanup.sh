#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/branch-cleanup.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "branch_cleanup_exists"
assert_file_exists "$TEST_SCRIPT" "branch-cleanup.sh should exist"

test_start "branch_cleanup_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "branch_cleanup_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "branch_cleanup_dry_by_default"
# The destructive path must be opt-in. APPLY defaults to 0, so a bare
# invocation can never delete.
assert_file_contains "$TEST_SCRIPT" 'APPLY="${APPLY:-0}"' \
  "APPLY should default to 0 (dry run)"

test_start "branch_cleanup_protects_gh_pages"
# gh-pages publishes a live site and is commonly an ancestor of the default
# branch, so a naive merged filter would delete it.
assert_file_contains "$TEST_SCRIPT" "gh-pages" \
  "gh-pages must be in the protected list"

test_start "branch_cleanup_protects_default_branches"
for b in main master develop trunk; do
  assert_file_contains "$TEST_SCRIPT" "$b" "$b must be protected"
done

test_start "branch_cleanup_requires_fetch_before_judging"
# "merged" judged against a stale origin ref is wrong. On the run this was
# written for, fetching first cut the candidate count from 294 to 144.
assert_file_contains "$TEST_SCRIPT" "git fetch --prune --quiet origin" \
  "must refresh refs before deciding what is merged"

test_start "branch_cleanup_guards_moved_branches"
# The safety property: a merged PR whose branch has since moved must be
# left alone, because the later commits are not in the default branch.
assert_file_contains "$TEST_SCRIPT" "LEAVE moved-since-pr" \
  "must leave branches that moved after their PR merged"

test_start "branch_cleanup_matches_pr_by_sha_not_name"
# Matching on head ref name alone would delete those moved branches.
assert_file_contains "$TEST_SCRIPT" "headRefOid" \
  "must compare against the PR head SHA, not just the ref name"

test_start "branch_cleanup_writes_restore_before_deleting"
# Remote deletion has no server-side undo, so the restore file is the only
# way back and must exist before the first deletion.
assert_file_contains "$TEST_SCRIPT" 'git push origin $sha:refs/heads/' \
  "restore script must record a remote re-push"
assert_file_contains "$TEST_SCRIPT" 'git branch -f' \
  "restore script must record a local branch re-point"

test_start "branch_cleanup_manifest_sorted_by_identity"
# Sorting by status makes a DRY->FAIL transition read as a delete plus an
# insert, which breaks reconciliation between runs.
assert_file_contains "$TEST_SCRIPT" 'sort -t$'"'"'\t'"'"' -k2,2 -k3,3 -k4,4' \
  "manifest must sort by repo/scope/branch, not status"

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

test_start "branch_cleanup_dry_run_deletes_nothing"
# End-to-end on a real repo: a branch merged into the default branch is
# reported as a candidate but must still exist afterwards.
sandbox="$(mktemp -d)"
(
  cd "$sandbox"
  mkdir -p repo && cd repo
  git init -q -b main .
  git config user.email t@example.com
  git config user.name t
  git config commit.gpgsign false
  echo a >a && git add a && git commit -qm a
  git checkout -qb feature/done
  echo b >b && git add b && git commit -qm b
  git checkout -q main
  git merge -q --no-ff feature/done -m merge
) >/dev/null 2>&1
out="$(BRANCH_CLEANUP_ROOT="$sandbox" NO_GH=1 bash "$TEST_SCRIPT" 2>&1 || true)"
if git -C "$sandbox/repo" show-ref --verify --quiet refs/heads/feature/done; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dry run left the branch in place"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dry run deleted a branch"
fi

test_start "branch_cleanup_writes_manifest"
manifest="$(find "$sandbox/.branch-cleanup" -name '*.manifest.tsv' 2>/dev/null | head -1)"
assert_not_empty "$manifest" "a manifest should be written"
rm -rf "$sandbox"

# Exercise the script under sandbox for line coverage (#883).
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
