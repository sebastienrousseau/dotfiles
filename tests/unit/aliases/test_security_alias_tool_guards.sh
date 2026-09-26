#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Behavioural tests for the tool guards in security/ufw-rules.aliases.sh
# and security/nmap-scanning.aliases.sh.
#
# Both files are concatenated into 91-ux-aliases-lazy.sh. They used to
# bail out with a top-level `command -v <tool> || return 0`, which, in
# the concatenated file, returned from the whole lazy layer: on a host
# without nmap or ufw every alias file after them (subversion,
# terraform, tmux, update, uuid, vagrant, wget, yarn) never loaded.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UFW_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/security/ufw-rules.aliases.sh"
NMAP_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/security/nmap-scanning.aliases.sh"

echo "Testing security alias tool guards..."

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home" "$SANDBOX/bare" "$SANDBOX/tools"

# Stubs: ufw, nmap and sudo only record how they were called.
for tool in ufw nmap sudo; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALL_LOG"\n' "$tool" >"$SANDBOX/tools/$tool"
  chmod +x "$SANDBOX/tools/$tool"
done

# Simulate the concatenated lazy layer: the alias file, then a line from
# the next alias file.
for name in ufw nmap; do
  src="$UFW_ALIASES"
  [[ "$name" == "nmap" ]] && src="$NMAP_ALIASES"
  cp "$src" "$SANDBOX/$name-layer.sh"
  printf '\nNEXT_FILE_LOADED=yes\n' >>"$SANDBOX/$name-layer.sh"
done

# run_in <tools-dir> <layer> <script>: source the layer in a clean bash
# whose PATH holds only <tools-dir> and the system dirs, then run <script>.
run_in() {
  env -i HOME="$SANDBOX/home" PATH="$1:/usr/bin:/bin" CALL_LOG="$SANDBOX/calls.log" \
    "$BASH" --norc --noprofile -c 'shopt -s expand_aliases; source "$1"; eval "$2"' _ "$2" "$3"
}

# --- Tool missing: skip the file, keep loading the layer ---

test_start "ufw_missing_does_not_stop_the_layer"
out="$(run_in "$SANDBOX/bare" "$SANDBOX/ufw-layer.sh" 'echo "${NEXT_FILE_LOADED:-no}"')"
assert_equals "yes" "$out" "without ufw, the file after ufw-rules still loads"

test_start "ufw_missing_defines_nothing"
out="$(run_in "$SANDBOX/bare" "$SANDBOX/ufw-layer.sh" 'alias fws 2>/dev/null; type -t fwallow || true')"
assert_empty "$out" "without ufw, no ufw alias or function is defined"

test_start "nmap_missing_does_not_stop_the_layer"
out="$(run_in "$SANDBOX/bare" "$SANDBOX/nmap-layer.sh" 'echo "${NEXT_FILE_LOADED:-no}"')"
assert_equals "yes" "$out" "without nmap, the file after nmap-scanning still loads"

test_start "nmap_missing_defines_nothing"
out="$(run_in "$SANDBOX/bare" "$SANDBOX/nmap-layer.sh" 'type -t nmscript || true')"
assert_empty "$out" "without nmap, nmscript is not defined"

# --- Tool present: define everything, still keep loading ---

test_start "ufw_present_defines_aliases"
out="$(run_in "$SANDBOX/tools" "$SANDBOX/ufw-layer.sh" 'alias fws; echo "${NEXT_FILE_LOADED:-no}"')"
assert_equals "alias fws='sudo ufw status'"$'\n'"yes" "$out" "with ufw, fws is defined and the layer continues"

test_start "nmap_present_defines_function"
out="$(run_in "$SANDBOX/tools" "$SANDBOX/nmap-layer.sh" 'type -t nmscript; echo "${NEXT_FILE_LOADED:-no}"')"
assert_equals "function"$'\n'"yes" "$out" "with nmap, nmscript is defined and the layer continues"

test_start "ufw_loaded_guard_skips_second_source"
out="$(env -i HOME="$SANDBOX/home" PATH="$SANDBOX/tools:/usr/bin:/bin" CALL_LOG="$SANDBOX/calls.log" \
  "$BASH" --norc --noprofile -c 'source "$1"; unalias fws; source "$1"; alias fws 2>/dev/null || echo skipped' _ "$UFW_ALIASES")"
assert_equals "skipped" "$out" "a second source is a no-op once _UFW_RULES_LOADED is set"

# --- Functions: usage errors and the command they run ---

# check_fn <layer> <fn> <expected-call> <args...>: with all args the
# function runs <expected-call>; with any one arg blank it prints usage,
# returns 1 and runs nothing.
check_fn() {
  local layer="$1" fn="$2" expected="$3"
  shift 3
  local args=("$@") i out rc
  : >"$SANDBOX/calls.log"
  test_start "${fn}_runs_command"
  rc=0
  run_in "$SANDBOX/tools" "$layer" "$fn$(printf ' %q' "${args[@]}")" >/dev/null || rc=$?
  assert_equals "0:$expected" "$rc:$(cat "$SANDBOX/calls.log")" "$fn ${args[*]} runs '$expected'"
  for i in "${!args[@]}"; do
    local blanked=("${args[@]}")
    blanked[i]=""
    : >"$SANDBOX/calls.log"
    test_start "${fn}_usage_when_arg$((i + 1))_blank"
    rc=0
    out="$(run_in "$SANDBOX/tools" "$layer" "$fn$(printf ' %q' "${blanked[@]}")")" || rc=$?
    assert_equals "1:Usage: $fn:" "$rc:${out%% <*}:$(cat "$SANDBOX/calls.log")" \
      "$fn with arg $((i + 1)) blank prints usage, returns 1, runs nothing"
  done
}

check_fn "$SANDBOX/ufw-layer.sh" fwallow "sudo ufw allow 22" 22
check_fn "$SANDBOX/ufw-layer.sh" fwallowproto "sudo ufw allow proto tcp from 10.0.0.1 to 10.0.0.2" tcp 10.0.0.1 10.0.0.2
check_fn "$SANDBOX/ufw-layer.sh" fwdeny "sudo ufw deny 23" 23
check_fn "$SANDBOX/ufw-layer.sh" fwdenyproto "sudo ufw deny proto udp from 10.0.0.3 to 10.0.0.4" udp 10.0.0.3 10.0.0.4
check_fn "$SANDBOX/ufw-layer.sh" fwdelete "sudo ufw delete allow 22" "allow 22"
check_fn "$SANDBOX/ufw-layer.sh" fwdeln "sudo ufw delete 3" 3
check_fn "$SANDBOX/ufw-layer.sh" fwlog "sudo ufw logging low" low
check_fn "$SANDBOX/nmap-layer.sh" nmscript "nmap --script vuln 10.0.0.5" vuln 10.0.0.5

echo ""
print_summary
