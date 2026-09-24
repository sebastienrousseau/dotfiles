#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Coverage for scripts/release-preflight branches not reached by
# tests/unit/qa/test_release_preflight.sh: --help, unknown options,
# --quiet, a non-Git REPO_ROOT and a predecessor tag that is not an
# ancestor of HEAD. Every run targets a throwaway repo in mktemp.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PREFLIGHT="$REPO_ROOT/scripts/release-preflight"
WORK="$(mktemp -d -t rp-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

_git() {
  git -C "$1" -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false -c tag.gpgSign=false "${@:2}"
}

# fixture <dir> <version> <previous>
fixture() {
  local root="$1"
  mkdir -p "$root/defaults" "$root/scripts"
  printf 'dotfiles_version = "%s"\nprevious_dotfiles_version = "%s"\n' "$2" "$3" \
    >"$root/defaults/.chezmoidata.toml"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$root/scripts/verify-release-versions"
  git -C "$root" init -q
  _git "$root" add .
  _git "$root" commit -q -m initial
}

run_pf() {
  local root="$1"
  shift
  REPO_ROOT="$root" bash "$PREFLIGHT" "$@" 2>&1
}

test_start "release_preflight_help"
rc=0
out="$(run_pf "$WORK" --help)" || rc=$?
assert_equals 0 "$rc" "--help exits 0"
assert_contains "Usage: scripts/release-preflight" "$out" "usage printed"

test_start "release_preflight_unknown_option"
rc=0
out="$(run_pf "$WORK" --bogus)" || rc=$?
assert_equals 2 "$rc" "unknown option exits 2"
assert_contains "unknown option: --bogus" "$out" "unknown option named"

test_start "release_preflight_not_a_worktree"
mkdir -p "$WORK/plain"
rc=0
out="$(GIT_CEILING_DIRECTORIES="$WORK" run_pf "$WORK/plain")" || rc=$?
assert_equals 1 "$rc" "non-git root fails"
assert_contains "is not a Git worktree" "$out" "non-git root diagnosed"

test_start "release_preflight_quiet_success"
fixture "$WORK/q" 1.2.3 1.2.2
_git "$WORK/q" tag --no-sign v1.2.2
rc=0
out="$(run_pf "$WORK/q" --quiet)" || rc=$?
assert_equals 0 "$rc" "quiet run succeeds"
assert_equals "" "$out" "quiet run prints nothing"

test_start "release_preflight_predecessor_not_ancestor"
fixture "$WORK/na" 1.2.3 1.2.2
main_branch="$(git -C "$WORK/na" symbolic-ref --short HEAD)"
_git "$WORK/na" checkout -q --orphan other
_git "$WORK/na" commit -q --allow-empty -m orphan
_git "$WORK/na" tag --no-sign v1.2.2
_git "$WORK/na" checkout -q "$main_branch"
rc=0
out="$(run_pf "$WORK/na" -q)" || rc=$?
assert_equals 1 "$rc" "non-ancestor predecessor fails"
assert_contains "is not an ancestor of HEAD" "$out" "non-ancestor predecessor diagnosed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
