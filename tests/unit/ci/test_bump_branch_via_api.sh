#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# tools/ci/bump-branch-via-api.sh, run in a fixture clone against a stub gh
# that logs every call: the bump commit is made through the API on a wip
# branch, the bump branch is then created or moved to it, and the wip branch
# is deleted however the run ends.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TOOL="$REPO_ROOT/tools/ci/bump-branch-via-api.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-bump-branch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# The stub logs one line per call. The bump branch exists when
# GH_STUB_EXISTS is set; the commit mutation fails when GH_STUB_FAIL is set
# and answers nothing when GH_STUB_EMPTY is set.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_STUB_LOG"
case "$*" in
  "api repos/owner/tap/git/ref/heads/"*) [[ -n "${GH_STUB_EXISTS:-}" ]] ;;
  "api graphql --input "*)
    cp "$4" "$GH_STUB_PAYLOAD"
    [[ -n "${GH_STUB_FAIL:-}" ]] && { echo "GraphQL: expectedHeadOid mismatch" >&2; exit 1; }
    [[ -n "${GH_STUB_EMPTY:-}" ]] || echo "c0ffee00" ;;
esac
EOF
chmod +x "$WORK/bin/gh"

# fixture NAME: a clone with one commit holding Formula/dot.rb.
fixture() {
  local repo="$WORK/$1"
  git init -q "$repo"
  mkdir -p "$repo/Formula"
  printf 'old\n' >"$repo/Formula/dot.rb"
  git -C "$repo" add -A
  git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false \
    commit -qm init
  printf '%s\n' "$repo"
}

# run REPO ARGS...: the tool's output in OUT, its status in RC, the gh
# calls in CALLS.
run() {
  local repo="$1"
  shift
  : >"$WORK/gh.log"
  RC=0
  OUT="$(cd "$repo" && PATH="$WORK/bin:$PATH" GH_STUB_LOG="$WORK/gh.log" GH_STUB_PAYLOAD="$WORK/payload.json" \
    GITHUB_RUN_ID=42 bash "$TOOL" "$@" 2>&1)" || RC=$?
  CALLS="$(cat "$WORK/gh.log")"
}

# nth N: the Nth gh call.
nth() { sed -n "${1}p" <<<"$CALLS"; }

test_start "new_branch_points_at_the_api_commit"
repo="$(fixture new)"
head="$(git -C "$repo" rev-parse HEAD)"
printf 'new\n' >"$repo/Formula/dot.rb"
run "$repo" owner/tap bump/dot-1.2.3 "dot 1.2.3"
assert_equals "0" "$RC" "the bump succeeds"
assert_equals "changed=true" "$OUT" "and reports a change"
assert_equals "api repos/owner/tap/git/refs -f ref=refs/heads/wip/bump/dot-1.2.3-42 -f sha=$head" \
  "$(nth 1)" "a wip branch starts at the checked-out head"
assert_equals "api graphql --input" "$(nth 2 | cut -d' ' -f1-3)" "the commit is made through the API"
assert_equals "api repos/owner/tap/git/refs -f ref=refs/heads/bump/dot-1.2.3 -f sha=c0ffee00" \
  "$(nth 4)" "the bump branch is created at that commit"
assert_equals "api -X DELETE repos/owner/tap/git/refs/heads/wip/bump/dot-1.2.3-42" \
  "$(nth 5)" "and the wip branch is deleted"

test_start "existing_branch_is_moved_not_reset_to_base"
# Moving the branch straight to the commit replaces an earlier bump without
# ever pointing it at the base head, which would mark its PR as merged.
repo="$(fixture existing)"
printf 'new\n' >"$repo/Formula/dot.rb"
GH_STUB_EXISTS=1 run "$repo" owner/tap bump/dot-1.2.3 "dot 1.2.3"
assert_equals "0" "$RC" "the re-run succeeds"
assert_equals "api -X PATCH repos/owner/tap/git/refs/heads/bump/dot-1.2.3 -f sha=c0ffee00 -F force=true" \
  "$(nth 4)" "the bump branch moves to the new commit"
assert_equals "1" "$(grep -c "heads/bump/dot-1.2.3 .*sha=" <<<"$CALLS")" \
  "and is written exactly once"

test_start "commit_runs_in_the_target_repository"
assert_equals "owner/tap wip/bump/dot-1.2.3-42" \
  "$(jq -r '.variables.input.branch | "\(.repositoryNameWithOwner) \(.branchName)"' "$WORK/payload.json")" \
  "the API commit names the tap, not this repository"

test_start "clean_tree_touches_nothing"
repo="$(fixture clean)"
run "$repo" owner/tap bump/dot-1.2.3 "dot 1.2.3"
assert_equals "0" "$RC" "a clean tree is not an error"
assert_equals "changed=false" "$OUT" "it reports no change"
assert_equals "" "$CALLS" "and makes no API call"

test_start "failed_commit_leaves_the_branch_alone"
repo="$(fixture fail)"
printf 'new\n' >"$repo/Formula/dot.rb"
GH_STUB_FAIL=1 run "$repo" owner/tap bump/dot-1.2.3 "dot 1.2.3"
assert_not_equals "0" "$RC" "a refused commit fails the step"
assert_contains "expectedHeadOid mismatch" "$OUT" "with GitHub's reason"
assert_equals "0" "$(grep -c "heads/bump/dot-1.2.3 \|ref=refs/heads/bump/dot-1.2.3 " <<<"$CALLS")" \
  "the bump branch is never written"
assert_contains "api -X DELETE repos/owner/tap/git/refs/heads/wip/bump/dot-1.2.3-42" "$CALLS" \
  "the wip branch is still deleted"

test_start "missing_commit_id_fails"
repo="$(fixture empty)"
printf 'new\n' >"$repo/Formula/dot.rb"
GH_STUB_EMPTY=1 run "$repo" owner/tap bump/dot-1.2.3 "dot 1.2.3"
assert_not_equals "0" "$RC" "an answer without a commit fails the step"
assert_contains "no commit was created" "$OUT" "and says so"

test_start "usage_error"
run "$WORK" owner/tap only-two
assert_equals "2" "$RC" "a missing headline is a usage error"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
