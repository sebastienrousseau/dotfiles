#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# tools/ci/commit-via-api.sh, run in a fixture repository against a stub gh:
# the createCommitOnBranch payload it sends must carry every change, the
# branch head it saw and the DCO sign-off.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TOOL="$REPO_ROOT/tools/ci/commit-via-api.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-commit-via-api.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# The stub records the --input payload and answers as the API would, or
# fails when GH_STUB_FAIL is set.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ -n "${GH_STUB_FAIL:-}" ]] && { echo "GraphQL: expectedHeadOid mismatch" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  [[ "$1" == --input ]] && cp "$2" "$GH_STUB_PAYLOAD"
  shift
done
echo "0123abcd"
EOF
chmod +x "$WORK/bin/gh"

# fixture NAME: a repository with one commit holding keep.txt and gone.txt.
fixture() {
  local repo="$WORK/$1"
  git init -q "$repo"
  printf 'old\n' >"$repo/keep.txt"
  printf 'bye\n' >"$repo/gone.txt"
  git -C "$repo" add -A
  git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false \
    commit -qm init
  printf '%s\n' "$repo"
}

# run REPO ARGS...: the tool's stdout in OUT, its status in RC.
run() {
  local repo="$1"
  shift
  rm -f "$WORK/payload.json"
  RC=0
  OUT="$(cd "$repo" && PATH="$WORK/bin:$PATH" GH_STUB_PAYLOAD="$WORK/payload.json" \
    GITHUB_REPOSITORY=owner/name bash "$TOOL" "$@" 2>&1)" || RC=$?
}

# field FILTER: a jq filter applied to the payload's mutation input.
field() {
  jq -r ".variables.input | $1" "$WORK/payload.json"
}

test_start "payload_carries_every_change"
repo="$(fixture changes)"
head="$(git -C "$repo" rev-parse HEAD)"
printf 'new\n' >"$repo/keep.txt"
printf 'added\n' >"$repo/dir with space.txt"
rm "$repo/gone.txt"
run "$repo" feat/v1.2.3 "chore: sync version references to v1.2.3"
assert_equals "0" "$RC" "the commit is created"
assert_equals "0123abcd" "$OUT" "and its oid is printed"
assert_equals "owner/name feat/v1.2.3" \
  "$(field '.branch | "\(.repositoryNameWithOwner) \(.branchName)"')" \
  "on the named branch of the repository"
assert_equals "$head" "$(field .expectedHeadOid)" "guarded by the head the job saw"
assert_equals "dir with space.txt keep.txt" \
  "$(field '[.fileChanges.additions[].path] | sort | join(" ")')" \
  "modified and untracked files are additions"
assert_equals "new" \
  "$(field '.fileChanges.additions[] | select(.path == "keep.txt") | .contents' | base64 -d)" \
  "with their new contents"
assert_equals "gone.txt" "$(field '[.fileChanges.deletions[].path] | join(" ")')" \
  "a removed file is a deletion"
assert_equals "chore: sync version references to v1.2.3" "$(field .message.headline)" \
  "the headline is the one given"
assert_equals "Signed-off-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>" \
  "$(field .message.body)" "the body is the bot's DCO sign-off"

test_start "large_file_is_sent_whole"
# Linux caps one argument at 128 KiB; CHANGELOG.md, a sync target, is
# larger once base64-encoded, so contents must never travel as an argument.
repo="$(fixture large)"
head -c 200000 /dev/zero | tr '\0' 'x' >"$repo/keep.txt"
run "$repo" feat/v1.2.3 "chore: x"
assert_equals "0" "$RC" "a 200 kB file commits"
assert_equals "200000" \
  "$(field '.fileChanges.additions[0].contents' | base64 -d | wc -c | tr -d ' ')" \
  "with every byte"

test_start "clean_tree_sends_nothing"
repo="$(fixture clean)"
run "$repo" feat/v1.2.3 "chore: x"
assert_equals "0" "$RC" "a clean tree is not an error"
assert_file_not_exists "$WORK/payload.json" "and no request is made"

test_start "api_failure_fails_the_step"
repo="$(fixture fail)"
printf 'new\n' >"$repo/keep.txt"
GH_STUB_FAIL=1 run "$repo" feat/v1.2.3 "chore: x"
assert_not_equals "0" "$RC" "a refused mutation fails the job"
assert_contains "expectedHeadOid mismatch" "$OUT" "with GitHub's reason"

test_start "usage_error"
run "$WORK" only-one-arg
assert_equals "2" "$RC" "a missing headline is a usage error"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
