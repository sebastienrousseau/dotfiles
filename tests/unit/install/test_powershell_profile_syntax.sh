#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Static-syntax test for the dotfiles PowerShell profile.
#
# Runs portably on Linux + macOS dev hosts (where pwsh may or may not
# be available). When `pwsh` is on PATH, the test parses the profile
# via [System.Management.Automation.PSParser]. When pwsh isn't
# available, the test asserts a smaller set of textual invariants so
# the PR-time CI gate still gets *some* signal from the file changing.
#
# Regression for: GH-860
# Why: PowerShell parity was previously aspirational. A profile with
# a syntax error would only surface during the Windows runner job
# (#860's reliability-gate addition). This static test catches the
# common case (typos, missing braces, unclosed strings) earlier in
# the PR cycle without spending Windows runner minutes.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

PROFILE="$REPO_ROOT/defaults/dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl"
CONTRACT="$REPO_ROOT/scripts/qa/powershell-contract.ps1"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "profile_exists"
assert_file_exists "$PROFILE" "PowerShell profile template should exist"

test_start "contract_script_exists"
assert_file_exists "$CONTRACT" "PowerShell parity contract script should exist"

test_start "profile_defines_dot_function"
assert_file_contains "$PROFILE" "function dot" \
  "profile must expose a 'dot' function so PowerShell users invoke the same CLI"

test_start "profile_defines_xdg_env"
assert_file_contains "$PROFILE" "XDG_CONFIG_HOME" \
  "profile must define XDG_CONFIG_HOME to match Unix shells"

test_start "profile_balanced_braces"
opens=$(grep -c '{' "$PROFILE" || true)
closes=$(grep -c '}' "$PROFILE" || true)
if [[ "$opens" -eq "$closes" ]]; then
  assert_exit_code 0 "true"
else
  echo "Brace mismatch: $opens opens vs $closes closes" >&2
  assert_exit_code 0 "false"
fi

# -----------------------------------------------------------------------------
# Behavioural: parse with pwsh if available
# -----------------------------------------------------------------------------

if command -v pwsh >/dev/null 2>&1; then
  test_start "profile_parses_with_pwsh"
  # Render the template (strip chezmoi `{{ ... }}` blocks) then parse.
  rendered=$(mktemp -t pwsh-profile.XXXXXX.ps1)
  sed -E 's/\{\{[^}]+\}\}/0.0.0-fallback/g' "$PROFILE" > "$rendered"
  if pwsh -NoProfile -Command "
      \$ErrorActionPreference = 'Stop'
      try {
          \$tokens = \$errors = \$null
          [System.Management.Automation.Language.Parser]::ParseFile(
              '$rendered',
              [ref]\$tokens,
              [ref]\$errors
          ) | Out-Null
          if (\$errors -and \$errors.Count -gt 0) {
              foreach (\$e in \$errors) { Write-Error \$e.Message }
              exit 1
          }
          exit 0
      } catch {
          Write-Error \$_
          exit 1
      }
  " >/dev/null 2>&1; then
    assert_exit_code 0 "true"
  else
    pwsh -NoProfile -Command "
        \$tokens = \$errors = \$null
        [System.Management.Automation.Language.Parser]::ParseFile('$rendered', [ref]\$tokens, [ref]\$errors) | Out-Null
        \$errors | ForEach-Object { Write-Host \$_.Message }
    " >&2 || true
    assert_exit_code 0 "false  # pwsh reported parse errors"
  fi
  rm -f "$rendered"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
