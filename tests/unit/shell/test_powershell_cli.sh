#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DISPATCHER="$REPO_ROOT/bin/dot.ps1"
MODULE="$REPO_ROOT/scripts/dot/powershell/Dot.psm1"
SMOKE="$REPO_ROOT/tools/ci/windows-smoke-test.ps1"

test_start "powershell_dispatcher_exists"
assert_file_exists "$DISPATCHER" "native dispatcher exists"
test_start "powershell_module_exists"
assert_file_exists "$MODULE" "native module exists"
test_start "powershell_smoke_exists"
assert_file_exists "$SMOKE" "Windows smoke test exists"

for function in Get-DotVersion Invoke-DotHelp Test-DotAgentsSync \
  Invoke-DotChezmoi Get-DotStatus Get-DotSourcePath Invoke-DotDoctor \
  Get-DotEnvironment Get-DotAgents Get-DotFleetStatus; do
  test_start "powershell_exports_${function}"
  assert_file_contains "$MODULE" "$function" "module exposes $function"
done

for command in status diff apply sync update add remove init cd doctor env fleet agents; do
  test_start "powershell_dispatches_${command}"
  assert_file_contains "$DISPATCHER" "'$command'" "dispatcher handles $command"
done

test_start "powershell_ci_analyzes_module"
assert_file_contains "$SMOKE" "scripts/dot/powershell/Dot.psm1" \
  "PSScriptAnalyzer covers the native module"
test_start "powershell_ci_analyzes_dispatcher"
assert_file_contains "$SMOKE" "bin/dot.ps1" \
  "PSScriptAnalyzer covers the native dispatcher"

pwsh_version="$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.Major' 2>/dev/null || true)"
if [[ "$pwsh_version" =~ ^[0-9]+$ ]]; then
  for file in "$DISPATCHER" "$MODULE" "$SMOKE"; do
    test_start "powershell_parses_$(basename "$file" | tr '.-' '__')"
    if DOT_PS_FILE="$file" pwsh -NoProfile -Command '
      $tokens = $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile(
        $env:DOT_PS_FILE, [ref]$tokens, [ref]$errors) | Out-Null
      if ($errors.Count -gt 0) { exit 1 }
    ' >/dev/null 2>&1; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
    fi
  done
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
