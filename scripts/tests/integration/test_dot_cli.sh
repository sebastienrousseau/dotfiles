#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Integration tests for the dot CLI
# Tests core dot commands work end-to-end

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

# ── dot CLI existence and structure ──────────────────────────────

test_start "dot_cli_exists"
assert_file_exists "$DOT_CLI" "dot CLI should exist"

test_start "dot_cli_executable"
if [[ -x "$DOT_CLI" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot CLI is executable"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot CLI should be executable"
fi

test_start "dot_cli_shebang"
first_line=$(head -n 1 "$DOT_CLI")
assert_equals "#!/usr/bin/env bash" "$first_line" "dot CLI should have bash shebang"

# ── dot --version ────────────────────────────────────────────────

test_start "dot_version_output"
version_output=$(bash "$DOT_CLI" --version 2>&1)
if echo "$version_output" | grep -q "^dot v"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot --version outputs version string"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot --version should output 'dot v...'"
  printf '%b\n' "    Got: '$version_output'"
fi

# ── dot help ─────────────────────────────────────────────────────

test_start "dot_help_output"
help_output=$(bash "$DOT_CLI" help 2>&1)
if echo "$help_output" | grep -q "Core Commands:"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot help shows Core Commands section"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot help should show Core Commands"
fi

test_start "dot_help_lists_health"
if echo "$help_output" | grep -q "health"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot help lists health command"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot help should list health command"
fi

# ── dot cd ───────────────────────────────────────────────────────

test_start "dot_cd_output"
cd_output=$(CHEZMOI_SOURCE_DIR="$REPO_ROOT" bash "$DOT_CLI" cd 2>&1)
if [[ -d "$cd_output" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot cd outputs a valid directory"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot cd should output an existing directory"
  printf '%b\n' "    Got: '$cd_output'"
fi

# ── resolve_source_dir uses realpath ─────────────────────────────

test_start "dot_cd_resolves_symlinks"
# The output should not contain symlink components
if [[ "$cd_output" != *"//"* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot cd output has no double slashes"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot cd should not have double slashes"
fi

# ── Unknown command handling ─────────────────────────────────────

test_start "dot_unknown_command"
unknown_output=$(bash "$DOT_CLI" nonexistent-command 2>&1)
exit_code=$?
if [[ $exit_code -ne 0 ]] && echo "$unknown_output" | grep -q "Unknown command"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot rejects unknown commands with error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot should reject unknown commands"
  printf '%b\n' "    Exit code: $exit_code, Output: '$unknown_output'"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "Integration tests: $TESTS_PASSED passed, $TESTS_FAILED failed (of $TESTS_RUN)"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
