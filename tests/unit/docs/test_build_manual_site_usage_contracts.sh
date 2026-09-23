#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Usage contract of tools/docs/build-manual-site.sh. The mutation gate
# found both usage-error exits unprotected (`exit 64` -> `exit 0`
# survived): a usage error must exit with EX_USAGE (64), not success,
# so a CI step mis-spelling a flag fails loudly. Pinned here:
#   - an unknown argument exits 64 with "unknown argument: <arg>"
#   - a --base-path that does not start and end with '/' exits 64 with
#     the boundary message (both a missing trailing and a missing leading
#     slash)
#   - a well-formed --base-path gets past the usage checks (control: the
#     next gate, a missing ssg, exits 127)
#   - an ssg older than the minimum exits 1 naming both versions (the
#     gate also reported this exit unprotected)
# Every case stops before ssg or python3 run: nothing is built, nothing
# is written, nothing reaches the network.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BUILD="$REPO_ROOT/tools/docs/build-manual-site.sh"

WORK="$(mktemp -d -t manual-site-usage.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

build() { # build args... — SSG points at a binary that does not exist
  B_ERR="$(HOME="$WORK" SSG="$WORK/no-such-ssg" bash "$BUILD" "$@" 2>&1 >/dev/null </dev/null)"
  B_RC=$?
}

test_start "build_manual_site_unknown_argument_exits_64"
build --bogus
assert_equals "64" "$B_RC" "an unknown argument is EX_USAGE"
assert_equals "build-manual-site: unknown argument: --bogus" "$B_ERR" \
  "stderr names the offending argument"

test_start "build_manual_site_base_path_without_trailing_slash_exits_64"
build --base-path /manual
assert_equals "64" "$B_RC" "a base path without a trailing slash is EX_USAGE"
assert_equals "build-manual-site: --base-path must start and end with '/'" "$B_ERR" \
  "stderr states the slash rule"

test_start "build_manual_site_base_path_without_leading_slash_exits_64"
build --base-path manual/
assert_equals "64" "$B_RC" "a base path without a leading slash is EX_USAGE"
assert_equals "build-manual-site: --base-path must start and end with '/'" "$B_ERR" \
  "stderr states the slash rule"

test_start "build_manual_site_valid_base_path_reaches_ssg_check"
build --base-path /manual/ --out "$WORK/out"
assert_equals "127" "$B_RC" "a valid base path passes usage checks and stops at the missing ssg"
assert_contains "ssg not found" "$B_ERR" "the next gate is the ssg lookup"
assert_file_not_exists "$WORK/out" "nothing is built without ssg"

test_start "build_manual_site_old_ssg_exits_1"
printf '#!/bin/sh\necho "ssg 0.0.1"\n' >"$WORK/old-ssg"
chmod +x "$WORK/old-ssg"
B_ERR="$(HOME="$WORK" SSG="$WORK/old-ssg" bash "$BUILD" --out "$WORK/out" 2>&1 >/dev/null </dev/null)"
B_RC=$?
assert_equals "1" "$B_RC" "an ssg below the minimum is a hard failure"
assert_equals "build-manual-site: ssg 0.0.1 is older than 0.0.63" "$B_ERR" \
  "stderr names the found and required versions"
assert_file_not_exists "$WORK/out" "nothing is built with an old ssg"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
