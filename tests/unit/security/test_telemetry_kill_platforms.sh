#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform dispatch in scripts/security/telemetry-kill.sh.
#
# The script does different work on Linux, macOS and everything else, and on
# any one machine only one of those arms can run — so the Linux block was
# unreachable from a macOS developer box and the macOS block from CI. A uname
# stub decides which arm is taken.
#
# Every case runs --dry-run, so the sudo calls inside those arms are printed
# rather than executed: nothing here can change the host's telemetry settings.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

TK_FILE="$REPO_ROOT/scripts/security/telemetry-kill.sh"

WORK="$(mktemp -d -t telemetry.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs"
dot_fixture_basebin "$WORK/base"

tk_uname() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$1" >"$WORK/stubs/uname"
  chmod +x "$WORK/stubs/uname"
}

TK_OUT=""
TK_RC=0
tk_run() {
  TK_RC=0
  TK_OUT="$(
    PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
      "${BASH:-bash}" "$TK_FILE" "$@" 2>&1 </dev/null
  )" || TK_RC=$?
}

test_start "telemetry_kill_disables_ubuntu_reporting_on_linux"
tk_uname Linux
tk_run --dry-run
assert_equals "0" "$TK_RC" "the Linux arm should exit 0 under --dry-run"
assert_contains "Ubuntu crash reporting" "$TK_OUT" \
  "the Linux arm should name the Ubuntu services"
assert_contains "popularity-contest" "$TK_OUT" \
  "and the popularity-contest service"
assert_contains "[dry-run]" "$TK_OUT" \
  "every command should be printed rather than run"

test_start "telemetry_kill_disables_analytics_on_macos"
tk_uname Darwin
tk_run --dry-run
assert_equals "0" "$TK_RC" "the macOS arm should exit 0 under --dry-run"
assert_contains "macOS analytics" "$TK_OUT" "the macOS arm should name analytics"

test_start "telemetry_kill_refuses_an_unsupported_os"
tk_uname SunOS
tk_run --dry-run
assert_equals "1" "$TK_RC" "an unrecognised OS should exit 1"
assert_contains "Unsupported OS" "$TK_OUT" "the refusal should say why"

test_start "telemetry_kill_requires_an_opt_in_outside_dry_run"
tk_uname Darwin
tk_run
assert_equals "1" "$TK_RC" "a live run without the opt-in should exit 1"
assert_contains "disabled by default" "$TK_OUT" \
  "the refusal should point at the opt-in variable"

print_summary
