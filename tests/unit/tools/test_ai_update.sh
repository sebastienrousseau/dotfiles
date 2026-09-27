#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# ai-update runs every updater even when one fails, reports each failure,
# and exits 1 if any failed. Every external command is a stub in a sandbox
# (sudo only records), so nothing is updated for real.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AIU="$REPO_ROOT/defaults/dot_local/bin/executable_ai-update"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# aiu <os> "<present tools>" "<failing tools>": run ai-update; sets rc/out.
aiu() {
  local os="$1" present="$2" failing="$3" t p d="$WORK/case"
  rm -rf "$d" && mkdir -p "$d/home" "$d/stubs" "$d/tools"
  for t in awk sed grep tr head tail cat mktemp rm chmod printf dirname basename env; do
    p="$(command -v "$t" 2>/dev/null || true)"
    [[ -n "$p" && "$p" == /* ]] && ln -s "$p" "$d/tools/$t"
  done
  mk() {
    {
      printf '#!%s\n' "$REAL_BASH"
      [[ " $failing " == *" $1 "* ]] && printf 'exit 1\n'
      printf '%s\n' "$2"
    } >"$d/stubs/$1"
    chmod +x "$d/stubs/$1"
  }
  mk chezmoi "echo '$REPO_ROOT/defaults'"
  mk uname "case \"\${1:-}\" in -m) echo x86_64 ;; *) echo $os ;; esac"
  mk sudo 'exit 0'
  mk curl 'exit 1'
  for t in $present; do
    case "$t" in
      node) mk node 'echo v24.1.0' ;;
      mise) mk mise '[ "${1:-}" = --version ] && echo "2026.9.9 macos-arm64"; exit 0' ;;
      ollama) mk ollama 'echo "ollama version is 0.9.1"' ;;
      *) mk "$t" 'exit 0' ;;
    esac
  done
  rc=0
  out="$(env -i HOME="$d/home" PATH="$d/stubs:$d/tools:/usr/bin:/bin" TERM=dumb TMPDIR="$d" \
    "$REAL_BASH" "$AIU" </dev/null 2>&1)" || rc=$?
}

test_start "ai_update_clean_run_exits_0"
aiu Darwin "mise brew node pipx claude" ""
assert_equals "0" "$rc" "every updater succeeded"

test_start "ai_update_clean_run_says_ready"
assert_contains "Dotfiles Environment Ready" "$out" "the ready banner"

test_start "ai_update_brew_failure_is_reported_not_done"
aiu Darwin "mise brew pipx" "brew"
assert_contains "brew update/upgrade failed" "$out" "a failing brew is an error, not 'done'"

test_start "ai_update_continues_after_a_failure"
assert_contains "Pipx tools" "$out" "later updaters still run"

test_start "ai_update_exits_1_when_anything_failed"
assert_equals "1" "$rc" "the run reports the failure in its status"

test_start "ai_update_summary_counts_failures"
assert_contains "1 update(s) failed" "$out" "the summary names the count"

test_start "ai_update_npm_failure_does_not_abort"
aiu Darwin "mise claude" "mise"
assert_contains "Claude Code" "$out" "a failing npm update no longer ends the run"

test_start "ai_update_pipx_failure_does_not_abort"
aiu Darwin "pipx lms" "pipx lms"
assert_contains "2 update(s) failed" "$out" "pipx and lms both counted"

test_start "ai_update_version_report_shows_na_for_missing_tools"
aiu Darwin "node" ""
assert_contains "N/A" "$(printf '%s\n' "$out" | grep 'Mise:')" "a missing mise reads N/A, not blank"

test_start "ai_update_version_report_shows_present_versions"
assert_contains "v24.1.0" "$(printf '%s\n' "$out" | grep 'Node:')" "node's version is shown"

test_start "ai_update_linux_sudo_failure_stops_early"
aiu Linux "mise" "sudo"
assert_equals "1:yes" "$rc:$([[ "$out" == *"Sudo required"* ]] && echo yes)" "no sudo, no system updates"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
