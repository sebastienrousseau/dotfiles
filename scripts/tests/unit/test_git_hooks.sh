#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for git hooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

HOOKS_DIR="$REPO_ROOT/scripts/git-hooks"

# Test: git-hooks directory exists
test_start "hooks_dir_exists"
assert_dir_exists "$HOOKS_DIR" "git-hooks directory should exist"

# Test: install.sh exists
test_start "hooks_install_exists"
if [[ -f "$HOOKS_DIR/install.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: install.sh should exist"
fi

# Test: install.sh valid syntax
test_start "hooks_install_syntax"
if [[ -f "$HOOKS_DIR/install.sh" ]] && bash -n "$HOOKS_DIR/install.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: install.sh syntax errors"
fi

# Test: all hook files have valid syntax
test_start "hooks_all_valid_syntax"
invalid=0
shopt -s nullglob
for script in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/hooks/*; do
  if [[ -f "$script" ]] && ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all hook files valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid files invalid"
fi

# Test: installs hooks to .git/hooks
test_start "hooks_installs_to_git"
if [[ -f "$HOOKS_DIR/install.sh" ]] && grep -qE '\.git/hooks|git.*hooks' "$HOOKS_DIR/install.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: installs to .git/hooks"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should install to .git/hooks"
fi

# Test: pre-commit or pre-push hooks exist
test_start "hooks_standard_hooks"
if find "$HOOKS_DIR" -name "pre-*" -o -name "commit-msg" 2>/dev/null | grep -q .; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: standard hooks exist"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have standard hooks"
fi

echo ""
echo "Git hooks tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
