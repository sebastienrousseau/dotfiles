#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091,SC2016
# The generated PowerShell cmdlets (ADR-020, N11): share/powershell/
# DotCommands.psm1 is what tools/docs/gen_cmdlets.py writes, it imports
# without an unapproved-verb warning, every built command is reachable from
# a cmdlet, each cmdlet runs its `dot` spelling with the arguments passed
# through, list and show share one Get cmdlet whose -Name picks show, and a
# destructive one honours -WhatIf. A fake `dot` records the calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

MODULE="$REPO_ROOT/share/powershell/DotCommands.psm1"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-cmdlets.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

test_start "module_matches_the_manifests"
rc=0
python3 "$REPO_ROOT/tools/docs/gen_cmdlets.py" --root "$REPO_ROOT" --check 2>"$WORK/err" || rc=$?
assert_equals "0" "$rc" "tools/docs/gen_cmdlets.py --check: $(cat "$WORK/err")"

test_start "a_stale_module_fails_the_check"
mkdir -p "$WORK/tree/share/powershell"
cp -R "$REPO_ROOT/plugins" "$REPO_ROOT/schemas" "$WORK/tree/"
printf '# edited\n' >"$WORK/tree/share/powershell/DotCommands.psm1"
rc=0
python3 "$REPO_ROOT/tools/docs/gen_cmdlets.py" --root "$WORK/tree" --check 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "an edited module fails --check"

test_start "every_built_command_has_a_cmdlet"
missing=""
while IFS='|' read -r rec key legacy _; do
  [[ "$rec" == cmd && -n "$legacy" ]] || continue
  grep -qF "dot $key " "$MODULE" || missing="$missing $key"
done <"$REPO_ROOT/lib/dot/data/commands.txt"
assert_equals "" "$missing" "each built spelling is run by some cmdlet"

test_start "cmdlets_run_their_spelling"
if ! command -v pwsh >/dev/null 2>&1; then
  assert_true "true" "pwsh not installed; skipped"
else
  cat >"$WORK/q.ps1" <<'PS'
param([string]$Module)
$global:DotCalls = @()
function global:dot { $global:DotCalls += ($args -join ' ') }
$warn = $null
Import-Module $Module -Force -WarningVariable warn -WarningAction SilentlyContinue
"warnings=" + @($warn).Count
"cmdlets=" + (Get-Command -Module DotCommands).Count
Get-DotDoctorStatus; Update-DotSystem --yes; Get-DotAi; New-DotSecretKey
Get-DotAgentMode; Get-DotAgentMode -Name ask; Get-DotAgentMode --json
Uninstall-DotConfig -WhatIf | Out-Null
"calls=" + ($global:DotCalls -join '|')
PS
  pwsh -NoProfile -File "$WORK/q.ps1" -Module "$MODULE" >"$WORK/out" 2>&1
  assert_file_contains "$WORK/out" "warnings=0" "every verb is an approved PowerShell verb"
  assert_file_contains "$WORK/out" "calls=doctor status|system update --yes|ai list|secret key new|agent mode list|agent mode show ask|agent mode list --json" \
    "each runs its spelling with its arguments; -Name picks show; -WhatIf stops a destructive one"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
