#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# A test that builds a throwaway repository must never write into the
# repository it runs from. Git exports GIT_DIR to hooks run in a linked
# worktree, so the pre-push suite inherited it there, and every fixture
# `git init` / `git commit` / `git tag` / `git config` landed in the real
# .git: moved branches, fixture tags, core.bare=true, gpgsign=false.
#
# Each case points the repo-local git variables at a decoy repository,
# runs a fixture repo build in a child that sources the framework, and
# checks the decoy is untouched.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DECOY="$TMP/decoy"
git init -q "$DECOY"
git -C "$DECOY" -c user.name=t -c user.email=t@t -c commit.gpgsign=false \
  commit -q --allow-empty -m decoy
DECOY_HEAD="$(git -C "$DECOY" rev-parse HEAD)"
DECOY_CONFIG="$(cat "$DECOY/.git/config")"

# _fixture_build <framework file>: in a child carrying the hook-style
# environment, source the framework file, then build a fixture repo the
# way the suites do. Prints the fixture's own HEAD subject.
# shellcheck disable=SC2016 # the child shell expands $1/$2, not this one
_fixture_build() {
  env GIT_DIR="$DECOY/.git" GIT_WORK_TREE="$DECOY" \
    GIT_INDEX_FILE="$DECOY/.git/index" GIT_COMMON_DIR="$DECOY/.git" \
    bash -c '
      source "$1"
      cd "$(mktemp -d "$2/fixture.XXXXXX")"
      git init -q .
      git config user.name fixture
      git config user.email fixture@example.com
      git config commit.gpgsign false
      git config tag.gpgsign false
      git commit -q --allow-empty -m fixture
      git tag v1
      git log -1 --format=%s
    ' _ "$1" "$TMP" 2>&1
}

for lib in assertions.sh git_env.sh; do
  out="$(_fixture_build "$REPO_ROOT/tests/framework/$lib")"

  test_start "git_env_${lib%.sh}_fixture_repo_builds"
  assert_equals "fixture" "$out" "the fixture repo gets its own commit"

  test_start "git_env_${lib%.sh}_decoy_head_untouched"
  assert_equals "$DECOY_HEAD" "$(git -C "$DECOY" rev-parse HEAD)" \
    "the decoy repository's HEAD did not move"

  test_start "git_env_${lib%.sh}_decoy_has_no_fixture_tag"
  assert_equals "" "$(git -C "$DECOY" tag -l v1)" "no fixture tag in the decoy"

  test_start "git_env_${lib%.sh}_decoy_config_untouched"
  assert_equals "$DECOY_CONFIG" "$(cat "$DECOY/.git/config")" \
    "the decoy's config gained no fixture identity or gpgsign override"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
