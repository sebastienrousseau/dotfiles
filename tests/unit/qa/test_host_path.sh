#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# tests/framework/host_path.sh: host_path_without mirrors the system bin
# directories minus the named tools, and refuses a directory that exists.
# shellcheck disable=SC1090,SC1091
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/host_path.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/host-path.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

test_start "host_path_keeps_the_base_system"
sys="$(host_path_without "$WORK/sys" sh)"
assert_equals "$WORK/sys" "$sys" "the directory is printed for PATH"
assert_true "PATH='$sys' command -v ls >/dev/null" "ls is still found"
assert_true "PATH='$sys' command -v cat >/dev/null" "cat is still found"

test_start "host_path_drops_the_named_tools"
assert_false "PATH='$sys' command -v sh >/dev/null" "a named tool is not found"
sys2="$(host_path_without "$WORK/sys2" cat ls)"
assert_false "PATH='$sys2' command -v cat >/dev/null" "the first of several is dropped"
assert_false "PATH='$sys2' command -v ls >/dev/null" "the last of several is dropped"
assert_true "PATH='$sys2' command -v sh >/dev/null" "an unnamed tool stays"

test_start "host_path_refuses_a_directory_that_exists"
mkdir -p "$WORK/existing"
: >"$WORK/existing/keep"
assert_false "host_path_without '$WORK/existing' ls 2>/dev/null" "an existing directory is refused"
assert_file_exists "$WORK/existing/keep" "and left untouched"
assert_false "host_path_without sys ls 2>/dev/null" "a bare name (an unset prefix) is refused"
assert_false "[[ -e sys ]]" "and nothing is created for it"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
