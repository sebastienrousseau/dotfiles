#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# commit-via-api.sh: commit the working tree's changes to BRANCH through the
# GraphQL createCommitOnBranch mutation instead of `git push`.
#
# GitHub signs a commit it creates for the job's token and shows it as
# verified, so a bot commit passes the branch rule that requires signed
# commits. A commit signed in the runner cannot: its committer address
# belongs to no GitHub account, so GitHub reports it as unverified_email.
#
# Usage: commit-via-api.sh BRANCH HEADLINE
# Needs: GH_TOKEN, GITHUB_REPOSITORY (owner/name), gh, jq, git.
# The body carries the DCO sign-off the "Check sign-off" job requires.
# Prints the new commit's oid; prints nothing and exits 0 when the tree is
# clean.
# =============================================================================

set -euo pipefail

BOT_IDENTITY='github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>'

# changes_json DIR: {"additions":[{path,contents}],"deletions":[{path}]} for
# every change against HEAD, untracked files included, renames as delete +
# add. Contents go through files under DIR, never as an argument: Linux caps
# one argument at 128 KiB and CHANGELOG.md is larger once base64-encoded.
changes_json() {
  local dir="$1" status path
  git add -A
  : >"$dir/changes.jsonl"
  while IFS= read -r -d '' status && IFS= read -r -d '' path; do
    if [[ "$status" == D ]]; then
      jq -nc --arg p "$path" '{deletion: {path: $p}}'
    else
      base64 <"$path" | tr -d '\n' >"$dir/contents"
      jq -nc --arg p "$path" --rawfile c "$dir/contents" \
        '{addition: {path: $p, contents: $c}}'
    fi >>"$dir/changes.jsonl"
  done < <(git diff --cached --no-renames --name-status -z HEAD)
  jq -sc '{additions: map(.addition // empty), deletions: map(.deletion // empty)}' \
    "$dir/changes.jsonl"
}

main() {
  if [[ $# -ne 2 ]]; then
    echo "usage: commit-via-api.sh BRANCH HEADLINE" >&2
    return 2
  fi
  local branch="$1" headline="$2" dir
  dir="$(mktemp -d)"
  trap 'rm -rf "$dir"' RETURN
  changes_json "$dir" >"$dir/changes.json"
  if [[ "$(jq '(.additions | length) + (.deletions | length)' "$dir/changes.json")" == 0 ]]; then
    echo "No changes to commit." >&2
    return 0
  fi
  jq -n \
    --arg repo "$GITHUB_REPOSITORY" --arg branch "$branch" \
    --arg head "$(git rev-parse HEAD)" --arg headline "$headline" \
    --arg body "Signed-off-by: $BOT_IDENTITY" --slurpfile changes "$dir/changes.json" '{
      query: "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }",
      variables: {input: {
        branch: {repositoryNameWithOwner: $repo, branchName: $branch},
        expectedHeadOid: $head,
        message: {headline: $headline, body: $body},
        fileChanges: $changes[0]
      }}
    }' >"$dir/payload.json"
  gh api graphql --input "$dir/payload.json" --jq '.data.createCommitOnBranch.commit.oid'
}

main "$@"
