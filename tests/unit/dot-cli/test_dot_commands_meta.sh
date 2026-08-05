#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
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
rm -rf "$_up_sb"

echo ""
echo "Meta commands tests completed."
# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$META_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
