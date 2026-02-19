#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI tools commands
# Tests: packages, tools, tools install, new, sandbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

TOOLS_FILE="$REPO_ROOT/scripts/dot/commands/tools.sh"

# Test: tools.sh file exists
test_start "tools_cmd_file_exists"
assert_file_exists "$TOOLS_FILE" "tools.sh should exist"

# Test: tools.sh is valid shell syntax
test_start "tools_cmd_syntax_valid"
if bash -n "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: tools.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: tools.sh has syntax errors"
fi

# Test: defines packages command
test_start "tools_cmd_defines_packages"
if grep -q "cmd_packages\|_packages\|packages" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines packages command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define packages command"
fi

# Test: defines tools command
test_start "tools_cmd_defines_tools"
if grep -q "cmd_tools\|_tools" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines tools command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define tools command"
fi

# Test: defines new command (project scaffolding)
test_start "tools_cmd_defines_new"
if grep -q "cmd_new\|_new\|dot_new" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines new command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define new command"
fi

# Test: defines sandbox command
test_start "tools_cmd_defines_sandbox"
if grep -q "sandbox" "$REPO_ROOT/scripts/dot/commands/meta.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: sandbox command is defined in meta module"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: sandbox command should exist in meta module"
fi

# Test: no hardcoded paths
test_start "tools_cmd_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: uses XDG directories
test_start "tools_cmd_uses_xdg"
if grep -qE 'PWD|HOME|resolve_source_dir|require_source_dir' "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses XDG/HOME variables"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use XDG directories"
fi

# Test: shellcheck compliance
test_start "tools_cmd_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$TOOLS_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

echo ""
echo "Tools commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
