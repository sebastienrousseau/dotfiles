#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# bump-branch-via-api.sh: point BRANCH of REPO at one commit holding the
# working tree's changes on top of its checked-out HEAD, made through
# tools/ci/commit-via-api.sh so GitHub signs it and shows it as verified.
# The Homebrew tap and Scoop bucket require signed commits; a commit signed
# in the runner showed there as unknown_key and blocked every bump PR.
#
# The commit is made on a temporary branch and BRANCH is then moved to it,
# so a re-run replaces an earlier bump (and its unverified commit) without
# BRANCH ever pointing at HEAD itself: a PR whose head is already in its
# base is marked as merged.
#
# Usage: bump-branch-via-api.sh REPO BRANCH HEADLINE
# Run inside a clone of REPO (owner/name). Needs: GH_TOKEN, gh, jq, git.
# Prints changed=true or changed=false for $GITHUB_OUTPUT.
# =============================================================================

set -euo pipefail

COMMIT_VIA_API="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/commit-via-api.sh"

# point_branch REPO BRANCH SHA: create BRANCH at SHA, or move it there.
point_branch() {
  if gh api "repos/$1/git/ref/heads/$2" >/dev/null 2>&1; then
    gh api -X PATCH "repos/$1/git/refs/heads/$2" -f sha="$3" -F force=true >/dev/null
  else
    gh api "repos/$1/git/refs" -f ref="refs/heads/$2" -f sha="$3" >/dev/null
  fi
}

main() {
  if [[ $# -ne 3 ]]; then
    echo "usage: bump-branch-via-api.sh REPO BRANCH HEADLINE" >&2
    return 2
  fi
  local repo="$1" branch="$2" headline="$3" wip oid
  if [[ -z "$(git status --porcelain)" ]]; then
    echo "changed=false"
    return 0
  fi
  wip="wip/${branch}-${GITHUB_RUN_ID:-$$}"
  gh api "repos/$repo/git/refs" -f ref="refs/heads/$wip" \
    -f sha="$(git rev-parse HEAD)" >/dev/null
  # The wip branch goes however the job ends, a failed commit included.
  # shellcheck disable=SC2064 # the names are fixed now, not at exit
  trap "gh api -X DELETE 'repos/$repo/git/refs/heads/$wip' >/dev/null 2>&1 || true" EXIT
  oid="$(GITHUB_REPOSITORY="$repo" bash "$COMMIT_VIA_API" "$wip" "$headline")"
  if [[ -z "$oid" ]]; then
    echo "bump-branch-via-api: no commit was created on $wip" >&2
    return 1
  fi
  point_branch "$repo" "$branch" "$oid"
  echo "changed=true"
}

main "$@"
