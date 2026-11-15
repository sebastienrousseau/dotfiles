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
source "$SCRIPT_DIR/../../framework/host_path.sh"

AIU="$REPO_ROOT/defaults/dot_local/bin/executable_ai-update"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# The tools each case stubs as present are missing from the base system.
SYS="$(host_path_without "$WORK/sys" brew claude goose lms mise node npm ollama pipx)"

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
      printf 'printf "%%s\\n" "%s $*" >>"%s/calls"\n' "$1" "$d"
      [[ " $failing " == *" $1 "* ]] && printf 'exit 1\n'
      printf '%s\n' "$2"
    } >"$d/stubs/$1"
    chmod +x "$d/stubs/$1"
  }
  mk chezmoi "echo '$REPO_ROOT/defaults'"
  mk uname "case \"\${1:-}\" in -m) echo ${AIU_ARCH:-x86_64} ;; *) echo $os ;; esac"
  mk sudo 'exit 0'
  mk curl 'exit 1'
  for t in $present; do
    case "$t" in
      node) mk node 'echo v24.1.0' ;;
      mise) mk mise '[ "${1:-}" = --version ] && echo "2026.9.9 macos-arm64"; exit 0' ;;
      ollama) mk ollama 'echo "ollama version is 0.9.1"' ;;
      # With no server running, ollama --version prints two warnings.
      ollama-noserver) mk ollama 'echo "Warning: could not connect to a running Ollama instance"
          echo "Warning: client version is 0.40.3"' ;;
      # An ollama mise manages: on PATH from a mise shims directory.
      mise-ollama) mk ollama 'echo "ollama version is 0.9.1"' && mkdir -p "$d/mise/shims" &&
        mv "$d/stubs/ollama" "$d/mise/shims/ollama" ;;
      # Homebrew with ollama as a formula only, or as a cask only.
      brew-formula) mk brew 'case "$1 ${2:-}" in "list --cask") exit 1 ;; esac; exit 0' ;;
      brew-cask) mk brew 'case "$1 ${2:-}" in "list --formula") exit 1 ;; esac; exit 0' ;;
      # pipx whose venvs lost their Python: upgrade-all fails until
      # reinstall-all has run.
      stale-pipx) mk pipx 'case "$1" in upgrade-all) [ -f "$HOME/reinstalled" ] && exit 0
          echo "Not upgrading ruff. It has an invalid python interpreter /x/bin/python."; exit 1 ;;
        reinstall-all) : >"$HOME/reinstalled" ;; esac' ;;
      local-goose) mkdir -p "$d/home/.local/bin" && printf '#!/bin/sh\n' >"$d/home/.local/bin/goose" &&
        chmod +x "$d/home/.local/bin/goose" ;;
      *) mk "$t" 'exit 0' ;;
    esac
  done
  rc=0
  out="$(env -i HOME="$d/home" PATH="$d/stubs:$d/mise/shims:$d/tools:$SYS" TERM=dumb TMPDIR="$d" \
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

test_start "ai_update_pipx_stale_interpreter_is_rebuilt"
aiu Darwin "stale-pipx" ""
assert_equals "0" "$rc" "the run succeeds once the venvs are rebuilt"
assert_equals "pipx upgrade-all|pipx reinstall-all|pipx upgrade-all" \
  "$(grep -E '^pipx (upgrade|reinstall)' "$WORK/case/calls" | paste -sd'|' -)" "upgrade, rebuild, upgrade again"

test_start "ai_update_pipx_other_failure_is_not_rebuilt"
aiu Darwin "pipx" "pipx"
assert_equals "1" "$rc" "a plain failure still fails"
assert_equals "pipx upgrade-all" "$(grep -E '^pipx (upgrade|reinstall)' "$WORK/case/calls" | paste -sd'|' -)" \
  "no reinstall without the stale-interpreter message"

test_start "ai_update_version_report_shows_na_for_missing_tools"
aiu Darwin "node" ""
assert_contains "N/A" "$(printf '%s\n' "$out" | grep 'Mise:')" "a missing mise reads N/A, not blank"

test_start "ai_update_version_report_shows_present_versions"
assert_contains "v24.1.0" "$(printf '%s\n' "$out" | grep 'Node:')" "node's version is shown"

test_start "ai_update_linux_sudo_failure_stops_early"
aiu Linux "mise" "sudo"
assert_equals "1:yes" "$rc:$([[ "$out" == *"Sudo required"* ]] && echo yes)" "no sudo, no system updates"

# A native tool installed only under ~/.local/bin (not on PATH) is still
# updated; one that is nowhere is left alone.
test_start "ai_update_reinstalls_a_tool_found_only_in_local_bin"
aiu Darwin "local-goose" ""
assert_contains "Goose" "$out" "the ~/.local/bin copy is found"

test_start "ai_update_skips_a_native_tool_that_is_not_installed"
aiu Darwin "" ""
assert_equals "no" "$([[ "$out" == *Goose* ]] && echo yes || echo no)" "no goose, no goose step"

test_start "ai_update_macos_ollama_upgrades_through_brew"
aiu Darwin "ollama brew-cask" ""
assert_file_contains "$WORK/case/calls" "brew upgrade --cask ollama" "brew is asked to upgrade the cask"

test_start "ai_update_macos_ollama_formula_upgrades_the_formula"
aiu Darwin "ollama brew-formula" ""
assert_equals "brew upgrade ollama" "$(grep 'upgrade.*ollama' "$WORK/case/calls")" \
  "brew upgrades the formula, not a cask"
assert_contains "done" "$(printf '%s\n' "$out" | grep -A1 'Ollama (macOS)')" "the formula upgrade is reported done"

test_start "ai_update_macos_ollama_from_mise_is_left_to_its_pin"
aiu Darwin "mise-ollama brew-formula" ""
assert_contains "pinned by mise" "$(printf '%s\n' "$out" | grep -A1 'Ollama (macOS)')" "the mise pin owns the version"
assert_equals "no" "$(grep -q 'brew upgrade.*ollama' "$WORK/case/calls" && echo yes || echo no)" \
  "a shadowed brew copy is not what runs, so it is not the update"

test_start "ai_update_macos_ollama_brew_failure_falls_back_to_the_app"
aiu Darwin "ollama brew-cask" "brew"
assert_contains "Update via App" "$(printf '%s\n' "$out" | grep -A1 'Ollama (macOS)')" "a failed brew upgrade is not reported as done"

test_start "ai_update_version_report_ignores_ollama_warnings"
aiu Darwin "ollama-noserver" ""
report="$(printf '%s\n' "$out" | tr -d '\033' | sed 's/\[[0-9;]*m//g' | grep -A1 '^Ollama:' | paste -sd'|' -)"
assert_equals "Ollama:      0.40.3|Pipx:        N/A" "$report" \
  "one line, the client version, not the word 'instance'"

test_start "ai_update_linux_ollama_unsupported_arch_is_skipped"
AIU_ARCH=riscv64 aiu Linux "ollama" ""
assert_equals "0:yes" "$rc:$([[ "$out" == *"unsupported arch"* ]] && echo yes)" "an unknown arch skips ollama and the run succeeds"

test_start "ai_update_linux_ollama_unsupported_arch_does_not_stop_the_run"
assert_contains "Dotfiles Environment Ready" "$out" "the summary still prints"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
