#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Usage contract of tools/docs/build-site.sh. The mutation gate found its
# argument and toolchain guards unprotected. Pinned here:
#   - no arguments and a well-formed --out both get past the usage checks
#     (control: the next gate, a missing ssg, exits 127 naming it);
#   - --out without a directory, and an unknown argument, exit 64 (EX_USAGE)
#     with the reason, so a CI step misspelling a flag fails loudly;
#   - an ssg older than the minimum exits 1 naming both versions;
#   - an ssg at the minimum passes the version check and reaches the build
#     (a stub ssg that refuses to build stops it there, exit 3).
# ssg is always a stub or absent; the only writes are under a mktemp TMPDIR.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BUILD="$REPO_ROOT/tools/docs/build-site.sh"
WORK="$(mktemp -d -t site-usage.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# build <ssg> args...: run with SSG pointed at <ssg>; sets B_RC and B_ERR.
build() {
  local ssg="$1"
  shift
  B_ERR="$(HOME="$WORK" TMPDIR="$WORK" SSG="$ssg" bash "$BUILD" "$@" 2>&1 >/dev/null </dev/null)"
  B_RC=$?
}
printf '#!/bin/sh\necho "ssg 0.0.1"\n' >"$WORK/old-ssg"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "ssg 0.0.63"; exit 0; }\necho "stub ssg: not building" >&2\nexit 3\n' >"$WORK/new-ssg"
chmod +x "$WORK/old-ssg" "$WORK/new-ssg"

test_start "build_site_no_arguments_reaches_ssg_check"
build "$WORK/no-such-ssg"
assert_equals "127" "$B_RC" "with no arguments the usage checks pass and the missing ssg stops it"
assert_contains "build-site: ssg not found" "$B_ERR" "the missing ssg is named"

test_start "build_site_out_with_directory_reaches_ssg_check"
build "$WORK/no-such-ssg" --out "$WORK/out"
assert_equals "127" "$B_RC" "--out DIR is accepted"
assert_file_not_exists "$WORK/out" "nothing is built without ssg"

test_start "build_site_out_without_directory_exits_64"
build "$WORK/no-such-ssg" --out
assert_equals "64" "$B_RC" "--out with no value is EX_USAGE"
assert_equals "build-site: --out needs a directory" "$B_ERR" "stderr states what is missing"

test_start "build_site_unknown_argument_exits_64"
build "$WORK/no-such-ssg" --bogus
assert_equals "64" "$B_RC" "an unknown argument is EX_USAGE"
assert_equals "build-site: unknown argument: --bogus" "$B_ERR" "stderr names the argument"

test_start "build_site_old_ssg_exits_1"
build "$WORK/old-ssg" --out "$WORK/out"
assert_equals "1" "$B_RC" "an ssg below the minimum is a hard failure"
assert_equals "build-site: ssg 0.0.1 is older than 0.0.63" "$B_ERR" "stderr names both versions"
assert_file_not_exists "$WORK/out" "nothing is built with an old ssg"

test_start "build_site_minimum_ssg_reaches_the_build"
build "$WORK/new-ssg" --out "$WORK/out"
assert_equals "3" "$B_RC" "an ssg at the minimum passes the version check and is asked to build"
assert_contains "stub ssg: not building" "$B_ERR" "the stub's build refusal is what stopped it"
assert_false '[[ "$B_ERR" == *"older than"* ]]' "the minimum version is not rejected"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
