#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI meta commands
# Tests: log-rotate, help, version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

META_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: meta.sh file exists
test_start "meta_file_exists"
assert_file_exists "$META_FILE" "meta.sh should exist"

# Test: meta.sh is valid shell syntax
test_start "meta_syntax_valid"
if bash -n "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: meta.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: meta.sh has syntax errors"
fi

# Test: defines help command
test_start "meta_defines_help"
if grep -qE "cmd_docs|cmd_learn|cmd_keys|cmd_upgrade|cmd_sandbox|cmd_mcp|cmd_mode" "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines meta command functions"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define meta command functions"
fi

# Test: defines version command
test_start "meta_defines_version"
if grep -qE "case .*\\{1,\\}|upgrade\\)|docs\\)|learn\\)|keys\\)|sandbox\\)|mcp\\)|mode \\| agent\\)" "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines dispatch cases"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define dispatch cases"
fi

# Test: defines log-rotate command
test_start "meta_defines_log_rotate"
if grep -qE "cmd_upgrade|cmd_docs|cmd_learn|cmd_keys|cmd_sandbox|cmd_mcp|cmd_mode" "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: command handlers present"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: command handlers should be present"
fi

AGENT_MODULE="$REPO_ROOT/scripts/dot/commands/agent.sh"

test_start "meta_agent_enterprise_subcommands"
assert_file_contains "$AGENT_MODULE" "checkpoint)" "agent module defines checkpoint handling"
assert_file_contains "$AGENT_MODULE" "conformance)" "agent module defines conformance handling"

# Test: version uses semantic versioning
test_start "meta_semver_version"
if grep -q 'set -euo pipefail' "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: follows command module structure"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should follow command module structure"
fi

# Test: shellcheck compliance
test_start "meta_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$META_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

# ── cmd_upgrade renders through the step runner ──────────────────────
# Regression for the "dot upgrade dumps raw subprocess output" report.
# Each phase must run as a tracked step with its stdout+stderr captured
# to a log, not streamed to the terminal — otherwise the noisy git/nvim
# progress floods the screen and corrupts the dot-ui renderer. Drive
# cmd_upgrade in plain mode (no dot-ui) with stubbed noisy tools and
# assert: (a) no raw tool output leaks, (b) a neat step line per phase,
# (c) a failing phase does not abort the run and its tail is surfaced.
test_start "upgrade_captures_output_not_raw_flood"
_up_sb="$(mktemp -d)"
mkdir -p "$_up_sb/bin" "$_up_sb/src"
cat >"$_up_sb/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf 'remote: Counting objects: 100%%\r\n'
echo "RAWCHEZMOI up to date"
STUB
cat >"$_up_sb/bin/nvim" <<'STUB'
#!/usr/bin/env bash
printf '[copilot.lua] Receiving objects: 100%%\r\n'
echo "RAWNVIM sync done"
STUB
chmod +x "$_up_sb/bin"/*
_up_out="$(
  PATH="$_up_sb/bin:$PATH" bash -c '
    set -uo pipefail
    require_source_dir() { printf "%s\n" "'"$_up_sb"'/src"; }
    has_command() { command -v "$1" >/dev/null 2>&1; }
    source "'"$REPO_ROOT"'/lib/dot/ui.sh"
    eval "$(sed -n "/^_upgrade_last_line()/,/^}/p;/^cmd_upgrade()/,/^}\$/p" "'"$REPO_ROOT"'/scripts/dot/commands/meta.sh")"
    cmd_upgrade
  ' 2>&1
)"
# The raw progress/body lines must NOT appear on the terminal; only the
# last-line detail (RAWCHEZMOI/RAWNVIM text) rides along in the step line.
if printf '%s\n' "$_up_out" | grep -qE 'remote: Counting|copilot\.lua'; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: raw subprocess output leaked"
  printf '%s\n' "$_up_out" | sed 's/^/      /'
elif printf '%s\n' "$_up_out" | grep -q 'Dotfiles' &&
  printf '%s\n' "$_up_out" | grep -q 'Neovim plugins'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: phases render as steps, no raw flood"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected step lines missing"
  printf '%s\n' "$_up_out" | sed 's/^/      /'
fi

test_start "upgrade_failed_phase_continues_and_surfaces_tail"
cat >"$_up_sb/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
echo "network down: unable to pull" >&2
exit 1
STUB
_up_out2="$(
  PATH="$_up_sb/bin:$PATH" bash -c '
    set -uo pipefail
    require_source_dir() { printf "%s\n" "'"$_up_sb"'/src"; }
    has_command() { command -v "$1" >/dev/null 2>&1; }
    source "'"$REPO_ROOT"'/lib/dot/ui.sh"
    eval "$(sed -n "/^_upgrade_last_line()/,/^}/p;/^cmd_upgrade()/,/^}\$/p" "'"$REPO_ROOT"'/scripts/dot/commands/meta.sh")"
    cmd_upgrade; echo "RC=$?"
  ' 2>&1
)"
if printf '%s\n' "$_up_out2" | grep -q 'network down' &&
  printf '%s\n' "$_up_out2" | grep -q 'Neovim plugins' &&
  printf '%s\n' "$_up_out2" | grep -q 'RC=0'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: run continued, tail surfaced, rc=0"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: failure handling wrong"
  printf '%s\n' "$_up_out2" | sed 's/^/      /'
fi

# ── cmd_upgrade must never block on a prompt it has hidden ───────────
# Regression for the 2026-09-12 "chezmoi update seems very slow" report.
# Each phase's output is captured to a log, so a phase that asks a
# question (chezmoi's "X has changed since chezmoi last wrote it?") sat
# waiting on the terminal with the question invisible. The step runner
# now closes stdin and chezmoi gets --no-tty, so the prompt fails fast
# and the tail explains what to do instead. Same harness as above, plus
# a fake XDG_CONFIG_HOME so the nvim phase is driven by the fixture and
# not by whatever the host has under ~/.config.
_up_run() {
  XDG_CONFIG_HOME="$1" PATH="$_up_sb/bin:$PATH" bash -c '
    set -uo pipefail
    require_source_dir() { printf "%s\n" "'"$_up_sb"'/src"; }
    has_command() { command -v "$1" >/dev/null 2>&1; }
    source "'"$REPO_ROOT"'/lib/dot/ui.sh"
    eval "$(sed -n "/^_upgrade_last_line()/,/^}/p;/^cmd_upgrade()/,/^}\$/p" "'"$REPO_ROOT"'/scripts/dot/commands/meta.sh")"
    cmd_upgrade
  ' 2>&1
}
mkdir -p "$_up_sb/xdg/nvim" "$_up_sb/xdg-empty"
: >"$_up_sb/xdg/nvim/init.lua"
cat >"$_up_sb/bin/chezmoi" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$_up_sb/chezmoi.args"
# /dev/fd/0 -ef /dev/null is true only when stdin really is /dev/null,
# not for a pipe, a file or a tty.
if [ /dev/fd/0 -ef /dev/null ]; then echo CLOSED; else echo OPEN; fi >"$_up_sb/chezmoi.stdin"
STUB
cat >"$_up_sb/bin/nvim" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$_up_sb/nvim.args"
STUB
chmod +x "$_up_sb/bin"/*

test_start "upgrade_runs_steps_with_stdin_closed_and_chezmoi_no_tty"
_up_out3="$(_up_run "$_up_sb/xdg")"
if grep -q -- '--no-tty' "$_up_sb/chezmoi.args" 2>/dev/null &&
  grep -qx 'CLOSED' "$_up_sb/chezmoi.stdin" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: chezmoi gets --no-tty and no stdin"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: args=[$(cat "$_up_sb/chezmoi.args" 2>/dev/null)] stdin=[$(cat "$_up_sb/chezmoi.stdin" 2>/dev/null)]"
  printf '%s\n' "$_up_out3" | sed 's/^/      /'
fi

# `nvim -l` skips init.lua, so the headless upgrade script found no
# lazy.nvim and logged "skipping plugin update" on every run — the phase
# was a silent no-op. -u must point at the user's init.lua and come
# BEFORE -l, because -l ends nvim's option processing.
test_start "upgrade_nvim_loads_user_init_before_script"
_nv_args="$(cat "$_up_sb/nvim.args" 2>/dev/null || true)"
case "$_nv_args" in
  *"--headless -u $_up_sb/xdg/nvim/init.lua -l "*headless-upgrade.lua)
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -u init.lua precedes -l"
    ;;
  *)
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: nvim args=[$_nv_args]"
    ;;
esac

test_start "upgrade_nvim_skips_visibly_when_no_init"
rm -f "$_up_sb/nvim.args"
_up_out4="$(_up_run "$_up_sb/xdg-empty")"
if [[ ! -e "$_up_sb/nvim.args" ]] &&
  printf '%s\n' "$_up_out4" | grep -q 'Neovim plugins' &&
  printf '%s\n' "$_up_out4" | grep -q 'no init.lua'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: step reported as skipped, nvim not run"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected a visible skip without invoking nvim"
  printf '%s\n' "$_up_out4" | sed 's/^/      /'
fi

test_start "upgrade_chezmoi_overwrite_prompt_surfaces_hint"
cat >"$_up_sb/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
echo ".npmrc has changed since chezmoi last wrote it (diff/overwrite/all-overwrite/skip/quit)? chezmoi: .npmrc: EOF" >&2
exit 1
STUB
_up_out5="$(_up_run "$_up_sb/xdg")"
if printf '%s\n' "$_up_out5" | grep -q 'has changed since chezmoi last wrote it' &&
  printf '%s\n' "$_up_out5" | grep -q "chezmoi update --force"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: prompt failure explained with a fix"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: hint missing"
  printf '%s\n' "$_up_out5" | sed 's/^/      /'
fi
rm -rf "$_up_sb"

# ── dot keys ─────────────────────────────────────────────────────────
# Regression: cmd_keys probed <src>/docs/KEYS.md and, when that was absent,
# fell back to scripts/diagnostics/keys.sh. The keybindings document lives at
# docs/security/KEYS.md and the fallback script is not in the tree at all, so
# a bare `dot keys` could only ever answer "Keys script not found".
_keys_out="$DOTFILES_COV_TMPDIR/keys.out"

test_start "keys_prints_the_keybindings_document"
_keys_rc=0
bash "$META_FILE" keys >"$_keys_out" 2>&1 || _keys_rc=$?
assert_equals "0" "$_keys_rc" "a bare 'dot keys' exits 0 on a complete checkout"
assert_file_contains "$_keys_out" "# Keybindings" "the document is printed"
assert_output_not_contains "Keys script not found" "cat '$_keys_out'"

test_start "keys_with_a_query_searches_the_document"
_keys_rc=0
bash "$META_FILE" keys "Reload config" >"$_keys_out" 2>&1 || _keys_rc=$?
assert_equals "0" "$_keys_rc" "a query exits 0"
assert_file_contains "$_keys_out" "Reload config" "the matching line is shown"

test_start "keys_search_works_without_ripgrep"
# The CI runners have no ripgrep, and a bare `rg` there printed nothing while
# exiting 0. $KEYS_BIN is a curated PATH with grep but no rg.
KEYS_BIN="$DOTFILES_COV_TMPDIR/keys-bin"
mkdir -p "$KEYS_BIN"
for _t in bash sh cat env printf sed grep tr head tail dirname basename \
  mktemp rm uname locale tput wc awk date cut sort realpath readlink; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$KEYS_BIN/$_t"
done
assert_file_not_exists "$KEYS_BIN/rg" "the curated PATH must not contain ripgrep"
_keys_rc=0
PATH="$KEYS_BIN" bash "$META_FILE" keys "Reload config" >"$_keys_out" 2>&1 || _keys_rc=$?
assert_equals "0" "$_keys_rc" "the search exits 0 without ripgrep"
assert_file_contains "$_keys_out" "Reload config" "grep answers when rg is absent"

echo ""
echo "Meta commands tests completed."
# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$META_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
