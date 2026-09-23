#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for rd: argument count, missing directory, unresolvable
# path, protected paths, the top-level-home confirmation prompt, rm
# failure and the happy path. HOME is a mktemp sandbox; every deletion
# happens inside it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/files/rd.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/rd-cov.XXXXXX")"
SANDBOX="$(cd "$SANDBOX" && pwd -P)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
cd "$SANDBOX" || exit 1

source "$FUNC_FILE"

test_start "wrong_argument_count"
out="$(rd 2>&1)"
rc=$?
assert_equals "1" "$rc" "no argument returns 1"
assert_contains "Please add one argument" "$out" "usage error"
out="$(rd a b 2>&1)"
assert_equals "1" "$?" "two arguments return 1"

test_start "missing_directory"
out="$(rd "$SANDBOX/nope" 2>&1)"
rc=$?
assert_equals "1" "$rc" "missing dir returns 1"
assert_contains "Directory does not exist: $SANDBOX/nope" "$out" "names missing dir"

test_start "unresolvable_directory"
mkdir -p "$SANDBOX/unres"
# A pwd that fails stands in for a directory we cannot cd into (root
# ignores mode 000, so a permission-based probe is not portable).
out="$(
  pwd() { return 1; }
  rd "$SANDBOX/unres" 2>&1
)"
rc=$?
assert_equals "1" "$rc" "unresolvable path returns 1"
assert_contains "Cannot resolve path: $SANDBOX/unres" "$out" "resolve error"
assert_true "[[ -d '$SANDBOX/unres' ]]" "directory left in place"

test_start "protected_home"
out="$(rd "$HOME" 2>&1)"
rc=$?
assert_equals "1" "$rc" "HOME is refused"
assert_contains "Refusing to delete protected path: $HOME" "$out" "protected message"
assert_true "[[ -d '$HOME' ]]" "HOME still exists"

test_start "protected_root"
out="$(rd / 2>&1)"
assert_equals "1" "$?" "/ is refused"
assert_contains "Refusing to delete protected path: /" "$out" "root protected"

test_start "top_level_home_declined"
mkdir -p "$HOME/project"
out="$(printf 'n\n' | rd "$HOME/project" 2>&1)"
rc=$?
assert_equals "1" "$rc" "declined prompt returns 1"
assert_contains "About to delete top-level home directory" "$out" "warns"
assert_contains "Aborted." "$out" "aborts"
assert_true "[[ -d '$HOME/project' ]]" "directory kept after decline"

test_start "top_level_home_confirmed"
out="$(printf 'y\n' | rd "$HOME/project" 2>&1)"
rc=$?
assert_equals "0" "$rc" "confirmed prompt returns 0"
assert_contains "Successfully deleted: $HOME/project" "$out" "deleted"
assert_false "[[ -d '$HOME/project' ]]" "directory removed"

test_start "rm_failure"
mkdir -p "$SANDBOX/work/stuck"
out="$(
  rm() { return 1; }
  rd "$SANDBOX/work/stuck" 2>&1
)"
rc=$?
assert_equals "1" "$rc" "rm failure returns 1"
assert_contains "Failed to delete: $SANDBOX/work/stuck" "$out" "failure message"

test_start "nested_delete"
mkdir -p "$SANDBOX/work/a/b"
: >"$SANDBOX/work/a/b/file"
out="$(rd "$SANDBOX/work/a" 2>&1)"
rc=$?
assert_equals "0" "$rc" "nested delete returns 0"
assert_contains "Successfully deleted: $SANDBOX/work/a" "$out" "success message"
assert_false "[[ -e '$SANDBOX/work/a' ]]" "tree removed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
