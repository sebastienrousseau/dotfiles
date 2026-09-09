#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform dispatch in dot_local/bin/executable_notify.
#
# The script branches on `uname -s`, so on any one machine only one arm can
# ever run and the Linux half was unreachable from a macOS developer box (and
# the macOS half from CI). Both are driven here with a uname stub, and the
# Linux arm's own fallback chain — notify-send, then a plain echo — is walked
# by controlling what is on the PATH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

NOTIFY="$REPO_ROOT/defaults/dot_local/bin/executable_notify"

WORK="$(mktemp -d -t notify.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs"
dot_fixture_basebin "$WORK/base"

# uname is the only thing standing between this test and the other platform's
# arm, so it is the one command the stub dir always carries.
nf_uname() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$1" >"$WORK/stubs/uname"
  chmod +x "$WORK/stubs/uname"
}

NF_OUT=""
NF_RC=0
nf_run() {
  NF_RC=0
  NF_OUT="$(
    PATH="$WORK/stubs:$WORK/base" \
      "${BASH:-bash}" "$NOTIFY" "$@" 2>&1 </dev/null
  )" || NF_RC=$?
}

# ── 1. macOS uses osascript ────────────────────────────────────────────────
test_start "notify_uses_osascript_on_macos"
nf_uname Darwin
dot_fixture_stub "$WORK/stubs" osascript 0
nf_run "Build" "finished"
assert_equals "0" "$NF_RC" "the macOS arm should exit 0"
assert_contains "osascript" "$NF_OUT" "osascript should be the delivery mechanism"
assert_contains "finished" "$NF_OUT" "the message should be passed through"

# ── 2. Linux prefers notify-send ───────────────────────────────────────────
test_start "notify_uses_notify_send_on_linux"
nf_uname Linux
dot_fixture_stub "$WORK/stubs" notify-send 0
nf_run "Build" "finished"
assert_equals "0" "$NF_RC" "the Linux arm should exit 0"
assert_contains "notify-send Build finished" "$NF_OUT" \
  "notify-send should receive the title and message"

# ── 3. Linux without notify-send falls back to stdout ──────────────────────
test_start "notify_falls_back_to_stdout"
rm -f "$WORK/stubs/notify-send"
nf_run "Build" "finished"
assert_equals "0" "$NF_RC" "the fallback should still exit 0"
assert_contains "Build: finished" "$NF_OUT" \
  "with no notifier at all the message should be printed"

# ── 4. Defaults ────────────────────────────────────────────────────────────
test_start "notify_defaults_the_title"
nf_run
assert_contains "Notification:" "$NF_OUT" \
  "a bare invocation should still carry the default title"

print_summary
