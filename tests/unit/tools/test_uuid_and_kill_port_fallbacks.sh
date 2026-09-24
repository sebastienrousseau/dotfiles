#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The tool-detection fallbacks in uuid and kill-port.
#
# uuid prefers uuidgen and kill-port prefers lsof; both are present on every
# machine the suite runs on, so the arms behind them had never executed. Each
# case here hands the script a PATH carrying only the tool it wants found.
#
# kill-port's process lookup is answered by stubs that report no process, so
# nothing on the host is ever signalled.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

BIN_DIR="$REPO_ROOT/defaults/dot_local/bin"

WORK="$(mktemp -d -t uuidkp.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs"
dot_fixture_basebin "$WORK/base" od
rm -f "$WORK/base/uuidgen" "$WORK/base/lsof" "$WORK/base/ss" "$WORK/base/netstat"

UK_OUT=""
UK_RC=0
uk_run() {
  local script="$1"
  shift
  UK_RC=0
  UK_OUT="$(
    PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
      "${BASH:-bash}" "$BIN_DIR/$script" "$@" 2>&1 </dev/null
  )" || UK_RC=$?
}

# ── 1. uuid without uuidgen ────────────────────────────────────────────────
# With uuidgen stubbed away, `uuid` tries the kernel source first and only
# then `od -x -N 16 /dev/urandom | head -1 | awk …`.
#
#   Linux   /proc/sys/kernel/random/uuid exists, so a real id is produced
#           and the fallback is never reached.
#   macOS   neither source exists, so the fallback runs. It used to read
#           /dev/urandom unbounded and rely on SIGPIPE from head's exit to
#           stop od; where SIGPIPE is ignored (GitHub's runners) od read
#           forever and a CI lane burned six hours on exactly this. `-N 16`
#           bounds the read, so the fallback is exercised here with the
#           signal ignored and a time limit: it must finish and produce an id.
if [[ -r /proc/sys/kernel/random/uuid ]]; then
  test_start "uuid_uses_the_kernel_source_when_uuidgen_is_absent"
  uk_run executable_uuid
  assert_equals "0" "$UK_RC" "the kernel source should produce an id"
  assert_true "[[ \"\$UK_OUT\" =~ ^[0-9a-fA-F-]{36}$ ]]" \
    "and it should be a well-formed uuid"
else
  test_start "uuid_urandom_fallback_finishes_with_sigpipe_ignored"
  UK_RC=0
  UK_OUT="$(run_with_timeout 20 bash -c '
    trap "" PIPE
    PATH="$1/stubs:$1/base" NO_COLOR=1 bash "$2/executable_uuid" 2>&1 </dev/null' _ "$WORK" "$BIN_DIR")" || UK_RC=$?
  assert_not_equals "124" "$UK_RC" "the fallback finishes (124 = od read /dev/urandom until the bound)"
  assert_equals "0" "$UK_RC" "the fallback produces an id"
  assert_true "[[ \"\$UK_OUT\" =~ ^[0-9a-f-]{36}$ ]]" \
    "and it is a well-formed lowercase uuid"
fi

# ── 2. kill-port walks its lookup tools ────────────────────────────────────
#
# Each stub prints nothing, so find_pid reports no process and kill-port
# stops before signalling anything.
# The lookup command's stderr is discarded by the script, so each stub
# records that it ran by touching a file instead.
test_start "kill_port_uses_ss_when_lsof_is_absent"
printf '#!/bin/sh\ntouch "%s"\nexit 0\n' "$WORK/ss-ran" >"$WORK/stubs/ss"
chmod +x "$WORK/stubs/ss"
uk_run executable_kill-port 3000
assert_file_exists "$WORK/ss-ran" "ss should be the tool consulted"
# The ss arm parses with GNU awk's three-argument match(), which BSD awk
# rejects — so what the run prints after consulting ss is platform-dependent.
# What holds everywhere is that nothing was signalled.
assert_false "[[ \"\$UK_OUT\" == *'Killed PID'* ]]" \
  "no process should be signalled when the lookup found nothing"

test_start "kill_port_uses_netstat_when_ss_is_absent_too"
rm -f "$WORK/stubs/ss"
printf '#!/bin/sh\ntouch "%s"\nexit 0\n' "$WORK/netstat-ran" >"$WORK/stubs/netstat"
chmod +x "$WORK/stubs/netstat"
uk_run executable_kill-port 3000
assert_file_exists "$WORK/netstat-ran" "netstat should be the tool consulted"

test_start "kill_port_stops_without_a_lookup_tool"
rm -f "$WORK/stubs/netstat"
uk_run executable_kill-port 3000
assert_not_equals "0" "$UK_RC" \
  "with no way to find the process, kill-port must not report success"

print_summary
