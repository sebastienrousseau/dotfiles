#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform classification in the environment function.
#
# `environment` maps `uname -s` onto a short OS name through a five-arm case.
# On any one machine only one arm can ever be taken, so four of them were
# unreachable. A uname stub decides which.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/system/environment.sh"

WORK="$(mktemp -d -t envfn.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

source "$FUNC_FILE"

mkdir -p "$WORK/stubs"
dot_fixture_basebin "$WORK/base"

# env_as <uname-string> — what `environment` reports when uname says that.
env_as() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$1" >"$WORK/stubs/uname"
  chmod +x "$WORK/stubs/uname"
  (PATH="$WORK/stubs:$WORK/base" environment 2>&1)
}

test_start "environment_reports_mac_for_darwin"
assert_equals "mac" "$(env_as Darwin)" "Darwin should classify as mac"

test_start "environment_reports_linux_for_linux"
assert_equals "linux" "$(env_as Linux)" "Linux should classify as linux"

test_start "environment_reports_win_for_mingw"
assert_equals "win" "$(env_as MINGW64_NT-10.0)" "MinGW should classify as win"

test_start "environment_reports_win_for_cygwin"
assert_equals "win" "$(env_as CYGWIN_NT-10.0)" "Cygwin should classify as win"

test_start "environment_reports_other_for_anything_else"
assert_equals "other" "$(env_as SunOS)" "an unrecognised kernel should classify as other"

print_summary
