#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for the dot CLI entry point (executable_dot)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

echo "Testing dot CLI entry point..."

# Test: dot CLI file exists
test_start "dot_cli_exists"
assert_file_exists "$DOT_CLI" "executable_dot should exist"

# Test: dot CLI has valid bash syntax
test_start "dot_cli_syntax"
assert_exit_code 0 "bash -n '$DOT_CLI'"

# Test: dot CLI has shebang
test_start "dot_cli_shebang"
first_line=$(head -n 1 "$DOT_CLI")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash shebang"
fi

# Test: dot CLI uses set -e
test_start "dot_cli_set_e"
assert_file_contains "$DOT_CLI" "set -e" "should use set -e for error handling"

# Test: dot --help shows onboarding overview
test_start "dot_cli_help"
output=$(bash "$DOT_CLI" help 2>&1) || true
if [[ "$output" == *"What it is"* ]] && [[ "$output" == *"Platforms"* ]] && [[ "$output" == *"Start"* ]]; then
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
if [[ "$output" == *"What it is"* ]]; then
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
# Extract subcommands from help text
help_output=$(bash "$DOT_CLI" help all 2>&1)
help_cmds=()
while IFS= read -r line; do
  # Match lines like "  apply       Description..."
  if [[ "$line" =~ ^[[:space:]]+((--[a-z-]+)|([a-z][-a-z0-9]+))[[:space:]] ]]; then
    help_cmds+=("${BASH_REMATCH[1]}")
  fi
done <<<"$help_output"

# Extract routed commands from the CLI registry
route_handlers=()
in_routes=0
while IFS= read -r line; do
  if [[ "$line" == "_dot_command_routes() {" ]]; then
    in_routes=1
    continue
  fi
  if [[ "$in_routes" -eq 1 ]] && [[ "$line" == "}" ]]; then
    break
  fi
  if [[ "$in_routes" -eq 1 ]] && [[ "$line" =~ ^([-[:alnum:]_]+)\|([[:alnum:]_-]+)$ ]]; then
    route_handlers+=("${BASH_REMATCH[1]}")
  fi
done <"$DOT_CLI"

missing_handlers=0
set +u
for cmd in "${help_cmds[@]}"; do
  found=false
  for handler in "${route_handlers[@]}"; do
    if [[ "$cmd" == "$handler" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == false ]]; then
    echo "    WARNING: help lists '$cmd' but no case handler found"
    missing_handlers=$((missing_handlers + 1))
  fi
done
set -u

if [[ $missing_handlers -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all help subcommands have handlers"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $missing_handlers help entries lack case handlers"
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
output=$(bash "$DOT_CLI" help doctor 2>&1) || true
if [[ "$output" == *"dot doctor"* ]] && [[ "$output" == *"Examples"* ]] && [[ "$output" == *"dot doctor -H"* ]]; then
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
if [[ "$output" == *"Dotfiles Command Reference"* ]] && [[ "$output" == *"sync"* ]] && [[ "$output" == *"version"* ]]; then
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

# Test: dot -v is alias for --version
test_start "dot_cli_v_flag"
output=$(bash "$DOT_CLI" -v 2>&1) || true
reference_output=$(bash "$DOT_CLI" --version 2>&1) || true
if [[ "$output" == "$reference_output" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -v matches --version output"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -v should match --version output"
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
if [[ "$output" == *"What it is"* ]]; then
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

# Test: dot add with no args shows usage
test_start "dot_cli_add_no_args"
set +e
output=$(CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" add 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage: dot add"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot add with no args shows usage"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot add with no args should show usage (ec=$ec, output=$output)"
fi

# Test: dot new with no args shows usage
test_start "dot_cli_new_no_args"
set +e
output=$(CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" new 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage: dot new <lang> <name>"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot new with no args shows usage"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot new with no args should show usage (ec=$ec, output=$output)"
fi

echo ""
echo "dot CLI tests completed."
print_summary
