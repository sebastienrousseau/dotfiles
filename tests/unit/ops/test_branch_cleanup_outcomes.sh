#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# branch-cleanup.sh outcomes: which repos are skipped (and not processed),
# the exact summary counts, a default branch outside the protected list,
# the restore line and the reconcile hint. Throwaway repos with local bare
# origins under a sandbox root; NO_GH=1, so only the ancestor criterion.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BC="$REPO_ROOT/scripts/ops/branch-cleanup.sh"
REAL_GIT="$(command -v git)"
W="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/bc-outcomes.XXXXXX")" && pwd -P)"
trap 'rm -rf "$W"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
g() { "$REAL_GIT" -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }

# mkrepo <name> [default-branch]: origin + clone; feat/done merged (ancestor),
# feat/wip unmerged, both pushed; local/done merged but local only.
mkrepo() {
  local name="$1" def="${2:-main}"
  g init -q --bare -b "$def" "$W/origins/$name.git"
  g clone -q "$W/origins/$name.git" "$W/root/$name" 2>/dev/null
  (
    cd "$W/root/$name" || exit 1
    g checkout -q -b "$def" 2>/dev/null
    echo a >a && g add a && g commit -qm a && g push -q origin "$def"
    g checkout -qb feat/done && echo b >b && g add b && g commit -qm b && g push -q origin feat/done
    g checkout -q "$def" && g merge -q --ff-only feat/done && g push -q origin "$def"
    g checkout -qb feat/wip && echo c >c && g add c && g commit -qm c && g push -q origin feat/wip
    g branch local/done "$def"
    g checkout -q "$def"
    g remote set-head origin "$def" >/dev/null 2>&1
  )
}

mkrepo good
mkrepo nextdef next
mkrepo dirty && echo x >>"$W/root/dirty/a"
mkrepo detached && g -C "$W/root/detached" checkout -q --detach main
mkrepo nofetch && g -C "$W/root/nofetch" remote set-url origin "$W/origins/missing.git"
mkrepo offdefault && g -C "$W/root/offdefault" checkout -q feat/wip

run() {
  OUT="$(env -i HOME="$W" PATH="/usr/bin:/bin:$(dirname "$REAL_GIT")" GIT_CONFIG_GLOBAL=/dev/null \
    GIT_CONFIG_NOSYSTEM=1 BRANCH_CLEANUP_ROOT="$W/root" NO_GH=1 "$@" bash "$BC" 2>&1 </dev/null)" ||
    OUT="$OUT
<exit $?>"
}
has() { [[ "$OUT" == *"$1"* ]] && echo yes || echo no; }
summary() { printf '%s\n' "$OUT" | grep '^==== ' | sed 's/  */ /g'; }

test_start "branch_cleanup_skipped_repos_are_not_processed"
run
for r in dirty detached nofetch offdefault; do
  assert_equals "yes:no" "$(has "SKIP $r ::"):$(has "=== $r ")" "$r is skipped and never walked"
done

test_start "branch_cleanup_dry_run_summary_counts"
# good + nextdef each: feat/done local+origin (DRY), local/done (DRY),
# feat/wip local+origin (LEFT) → 0 deleted, left=4; four repos skipped.
assert_equals "==== APPLY=0 deleted_local=0 deleted_remote=0 failed=0 left=4 skipped_repos=4 ====" \
  "$(summary)" "exact dry-run counts"

test_start "branch_cleanup_unprotected_default_branch_is_never_a_candidate"
assert_equals "no:no" "$(has 'local  next ('):$(has 'origin next (')" \
  "the default branch 'next' is not deleted even though it is its own ancestor"

test_start "branch_cleanup_dry_run_has_no_restore_line"
assert_equals "no" "$(has 'Restore:')" "no restore script without APPLY"

test_start "branch_cleanup_first_run_has_nothing_to_reconcile"
assert_equals "no" "$(has 'Reconcile against previous run')" "one manifest, nothing to diff"

test_start "branch_cleanup_second_run_reconciles_against_the_first"
first="$(ls "$W/root/.branch-cleanup/"*.manifest.tsv)"
sleep 1.1
run APPLY=1
assert_equals "yes:yes" "$(has 'Reconcile against previous run'):$(has "$first")" \
  "the hint names the earlier manifest"

test_start "branch_cleanup_apply_summary_counts"
# Per repo: feat/done and local/done deleted locally, feat/done on origin.
assert_equals "==== APPLY=1 deleted_local=4 deleted_remote=2 failed=0 left=4 skipped_repos=4 ====" \
  "$(summary)" "exact apply counts"

test_start "branch_cleanup_apply_prints_the_restore_script"
assert_equals "yes" "$(has 'Restore:')" "apply names its restore script"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
