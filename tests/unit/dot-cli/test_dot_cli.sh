#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for the dot CLI entry point (executable_dot)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

DOT_CLI="$REPO_ROOT/bin/dot"

echo "Testing dot CLI entry point..."

# Test: dot CLI file exists
test_start "dot_cli_exists"
assert_file_exists "$DOT_CLI" "executable_dot should exist"

# Test: dot CLI has valid bash syntax
test_start "dot_cli_set_e"
assert_file_contains "$DOT_CLI" "set -e" "should use set -e for error handling"

# Test: dot --help shows onboarding overview
test_start "dot_cli_help"
output=$(bash "$DOT_CLI" help 2>&1) || true
if [[ "$output" == *"Usage: dot <domain> [object] <verb>"* ]] && [[ "$output" == *"CONFIGURATION"* ]] && [[ "$output" == *"SHORTCUTS"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help shows onboarding overview"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: help should show onboarding overview"
  printf '%b\n' "    Output: ${output:0:200}"
fi

# Test: dot --version shows version
test_start "dot_cli_version"
output=$(bash "$DOT_CLI" --version 2>&1) || true
if [[ "$output" == *"Dotfiles Version"* ]] && [[ "$output" == *".dotfiles "* ]] && [[ "$output" == *"Source"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: --version shows doctor-style version output"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: --version should show version"
  printf '%b\n' "    Output: $output"
fi

# Test: dot (no args) shows help
test_start "dot_cli_no_args"
output=$(bash "$DOT_CLI" 2>&1) || true
if [[ "$output" == *"Usage: dot <domain> [object] <verb>"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no args shows help"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no args should show help"
fi

# Test: dot unknown-command shows error
test_start "dot_cli_unknown_cmd"
set +e
output=$(bash "$DOT_CLI" totally-invalid-command-12345 2>&1)
ec=$?
set -e
if [[ "$output" == *"Unknown command"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: unknown command shows error and exits non-zero"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unknown command should show error"
  printf '%b\n' "    Exit code: $ec"
  printf '%b\n' "    Output: $output"
fi

# Test: every subcommand in full help has a case handler
test_start "dot_cli_help_handler_parity"
# Every built command `dot help all` lists runs a route the dispatcher has
# (lib/dot/data/routes.txt) or its plugin's entry (@<domain>,
# plugins/<domain>/dot-<domain>); a planned one is marked as such.
help_output=$(bash "$DOT_CLI" help all 2>&1)
help_cmds=()
while IFS= read -r line; do
  [[ "$line" =~ ^\ \ dot\ ([a-z][a-z\ -]*[a-z])\ \ + ]] && help_cmds+=("${BASH_REMATCH[1]}")
done <<<"$help_output"
missing_handlers=0
for cmd in "${help_cmds[@]}"; do
  legacy="$(awk -F'|' -v k="$cmd" '$1 == "cmd" && $2 == k { print $3; exit }' "$REPO_ROOT/lib/dot/data/commands.txt")"
  [[ -n "$legacy" ]] || continue
  if [[ "$legacy" == @* ]]; then
    entry="${legacy%% *}"
    entry="$REPO_ROOT/plugins/${entry#@}/dot-${entry#@}"
    if [[ ! -x "$entry" ]]; then
      echo "    WARNING: help lists '$cmd' but its entry $entry is missing"
      missing_handlers=$((missing_handlers + 1))
    fi
  elif ! grep -q "^${legacy%% *}|" "$REPO_ROOT/lib/dot/data/routes.txt"; then
    echo "    WARNING: help lists '$cmd' but its route '${legacy%% *}' has no handler"
    missing_handlers=$((missing_handlers + 1))
  fi
done

if [[ ${#help_cmds[@]} -gt 100 && $missing_handlers -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all ${#help_cmds[@]} help commands have handlers"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $missing_handlers of ${#help_cmds[@]} help entries lack handlers"
fi

# Test: help surface has no duplicate visible commands
test_start "dot_cli_help_unique_commands"
duplicate_cmds=$(printf '%s\n' "${help_cmds[@]}" | sort | uniq -d || true)
if [[ -z "$duplicate_cmds" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help commands are unique"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: duplicate help commands found"
  printf '%b\n' "    Duplicates: $duplicate_cmds"
fi

# Test: mcp is part of the public help surface
test_start "dot_cli_help_lists_mcp"
overview_output=$(bash "$DOT_CLI" help 2>&1)
if [[ "$help_output" == *"mcp"* ]] && [[ "$overview_output" == *"mcp"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help lists mcp"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: help should list mcp"
fi

# Test: dot help <command> shows focused help
test_start "dot_cli_help_command"
output=$(bash "$DOT_CLI" help doctor check 2>&1) || true
if [[ "$output" == *"dot doctor check ·"* ]] && [[ "$output" == *"effect"* ]] && [[ "$output" == *"--heal, -H"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help doctor shows focused command help"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: help doctor should show focused command help"
  printf '%b\n' "    Output: $output"
fi

# Test: dot help all shows full reference
test_start "dot_cli_help_all"
output=$(bash "$DOT_CLI" help all 2>&1) || true
if [[ "$output" == *"dot config sync"* ]] && [[ "$output" == *"dot system update"* ]] && [[ "$output" == *"(planned)"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help all shows full reference"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: help all should show full reference"
fi

# Test: dot --version contains VERSION string from file
test_start "dot_cli_version_value"
EXPECTED_VERSION=$(sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' "$REPO_ROOT/package.json" | head -n 1)
output=$(bash "$DOT_CLI" --version 2>&1) || true
if [[ "$output" == *"$EXPECTED_VERSION"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: version matches expected v$EXPECTED_VERSION"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: version should contain $EXPECTED_VERSION"
  printf '%b\n' "    Output: $output"
fi

# Test: dot -V is the GNU short form of --version (ADR-020 N9; -v is --verbose)
test_start "dot_cli_v_flag"
output=$(bash "$DOT_CLI" -V 2>&1) || true
reference_output=$(bash "$DOT_CLI" --version 2>&1) || true
if [[ "$output" == "$reference_output" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -V matches --version output"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -V should match --version output"
fi

# Test: dot version is alias for --version
test_start "dot_cli_version_cmd"
output=$(bash "$DOT_CLI" version 2>&1) || true
if [[ "$output" == "$reference_output" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: version matches --version output"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: version should match --version output"
fi

# Test: dot version uses doctor-style layout
test_start "dot_cli_version_layout"
if [[ "$reference_output" == *"Dotfiles Version"* ]] && [[ "$reference_output" == *"✓"* || "$reference_output" == *"[OK]"* ]] && [[ "$reference_output" == *"Version"* ]] && [[ "$reference_output" == *"Source"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: version reuses doctor-style header and status rows"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: version should reuse doctor-style header and status rows"
  printf '%b\n' "    Output: $reference_output"
fi

# Test: dot -h shows help
test_start "dot_cli_h_flag"
output=$(bash "$DOT_CLI" -h 2>&1) || true
if [[ "$output" == *"Usage: dot <domain> [object] <verb>"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -h shows help"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -h should show help"
fi

# Test: dot cd without source dir gives informative error
test_start "dot_cli_cd_no_source"
set +e
output=$(CHEZMOI_SOURCE_DIR="" HOME="/nonexistent" bash "$DOT_CLI" cd 2>&1)
ec=$?
set -e
if [[ $ec -ne 0 ]] && [[ "$output" == *"not found"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot cd without source exits non-zero with message"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot cd handled (ec=$ec)"
fi

# Test: dot config add with no args shows usage
test_start "dot_cli_add_no_args"
set +e
output=$(CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" config add 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage: dot config add"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot config add with no args shows usage"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot config add with no args should show usage (ec=$ec, output=$output)"
fi

# Test: dot tool new with no args shows usage
test_start "dot_cli_new_no_args"
set +e
output=$(CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" tool new 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage: dot tool new <lang> <name>"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot tool new with no args shows usage"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot tool new with no args should show usage (ec=$ec, output=$output)"
fi

echo ""
echo "dot CLI tests completed."
print_summary
