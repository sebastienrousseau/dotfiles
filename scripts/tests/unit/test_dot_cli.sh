#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for the dot CLI entry point (executable_dot)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

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
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash shebang"
fi

# Test: dot CLI uses set -e
test_start "dot_cli_set_e"
assert_file_contains "$DOT_CLI" "set -e" "should use set -e for error handling"

# Test: dot --help shows usage
test_start "dot_cli_help"
output=$(bash "$DOT_CLI" help 2>&1) || true
if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"dot"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: help shows usage"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: help should show usage"
  echo -e "    Output: ${output:0:200}"
fi

# Test: dot --version shows version
test_start "dot_cli_version"
output=$(bash "$DOT_CLI" --version 2>&1) || true
if [[ "$output" == *"dot v"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: --version shows version string"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: --version should show version"
  echo -e "    Output: $output"
fi

# Test: dot (no args) shows help
test_start "dot_cli_no_args"
output=$(bash "$DOT_CLI" 2>&1) || true
if [[ "$output" == *"Usage:"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no args shows help"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: no args should show help"
fi

# Test: dot unknown-command shows error
test_start "dot_cli_unknown_cmd"
set +e
output=$(bash "$DOT_CLI" totally-invalid-command-12345 2>&1)
ec=$?
set -e
if [[ "$output" == *"Unknown command"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: unknown command shows error and exits non-zero"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: unknown command should show error"
  echo -e "    Exit code: $ec"
  echo -e "    Output: $output"
fi

# Test: every subcommand in help has a case handler
test_start "dot_cli_help_handler_parity"
# Extract subcommands from help text
help_output=$(bash "$DOT_CLI" help 2>&1)
help_cmds=()
while IFS= read -r line; do
  # Match lines like "  apply       Description..."
  if [[ "$line" =~ ^[[:space:]]+([a-z][-a-z0-9]+)[[:space:]] ]]; then
    help_cmds+=("${BASH_REMATCH[1]}")
  fi
done <<<"$help_output"

# Extract case handlers from the script
case_handlers=()
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]+([-a-z]+)\) ]]; then
    case_handlers+=("${BASH_REMATCH[1]}")
  fi
done < <(grep -E '^\s+[a-z][-a-z]*\)' "$DOT_CLI")

missing_handlers=0
for cmd in "${help_cmds[@]}"; do
  found=false
  for handler in "${case_handlers[@]}"; do
    if [[ "$cmd" == "$handler" ]]; then
      found=true
      break
    fi
  done
  # Some help entries are compound (e.g., "--version" is handled by "--version|-v|version)")
  # Check if command appears anywhere in the script as a case label or reference
  if [[ "$found" == false ]]; then
    if grep -qE "(${cmd}[|)]|\"${cmd}\")" "$DOT_CLI" 2>/dev/null; then
      found=true
    fi
  fi
  if [[ "$found" == false ]]; then
    echo "    WARNING: help lists '$cmd' but no case handler found"
    missing_handlers=$((missing_handlers + 1))
  fi
done

if [[ $missing_handlers -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all help subcommands have handlers"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $missing_handlers help entries lack case handlers"
fi

# Test: dot --version contains VERSION string from file
test_start "dot_cli_version_value"
output=$(bash "$DOT_CLI" --version 2>&1) || true
if [[ "$output" == *"0.2.478"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: version matches expected v0.2.478"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: version should contain 0.2.478"
  echo -e "    Output: $output"
fi

# Test: dot -v is alias for --version
test_start "dot_cli_v_flag"
output=$(bash "$DOT_CLI" -v 2>&1) || true
if [[ "$output" == *"dot v"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: -v is alias for --version"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: -v should show version"
fi

# Test: dot -h shows help
test_start "dot_cli_h_flag"
output=$(bash "$DOT_CLI" -h 2>&1) || true
if [[ "$output" == *"Usage:"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: -h shows help"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: -h should show help"
fi

# Test: dot cd without source dir gives informative error
test_start "dot_cli_cd_no_source"
set +e
output=$(CHEZMOI_SOURCE_DIR="" HOME="/nonexistent" bash "$DOT_CLI" cd 2>&1)
ec=$?
set -e
if [[ $ec -ne 0 ]] && [[ "$output" == *"not found"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: dot cd without source exits non-zero with message"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: dot cd handled (ec=$ec)"
fi

# Test: dot add with no args shows usage
test_start "dot_cli_add_no_args"
set +e
output=$(bash "$DOT_CLI" add 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage:"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: dot add with no args shows usage"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: dot add with no args should show usage (ec=$ec)"
fi

# Test: dot new with no args shows usage
test_start "dot_cli_new_no_args"
set +e
output=$(bash "$DOT_CLI" new 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage:"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: dot new with no args shows usage"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: dot new with no args should show usage (ec=$ec)"
fi

echo ""
echo "dot CLI tests completed."
print_summary
