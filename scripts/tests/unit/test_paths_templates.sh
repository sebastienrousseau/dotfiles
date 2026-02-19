#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for paths templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

PATHS_DIR="$REPO_ROOT/.chezmoitemplates/paths"

# Test: paths directory exists
test_start "paths_dir_exists"
assert_dir_exists "$PATHS_DIR" "paths directory should exist"

# Test: default paths file exists
test_start "paths_default_exists"
if [[ -f "$PATHS_DIR/00-default.paths.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: default paths exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: default paths should exist"
fi

# Test: all paths files valid syntax
test_start "paths_all_valid_syntax"
invalid=0
for script in "$PATHS_DIR"/*.sh; do
  if [[ -f "$script" ]] && ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all paths files valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid files invalid"
fi

# Test: sets PATH variable
test_start "paths_sets_path"
if grep -rqE 'PATH=|path_prepend|export PATH' "$PATHS_DIR"/*.sh 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: sets PATH variable"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should set PATH variable"
fi

# Test: no hardcoded user paths
test_start "paths_no_hardcoded"
if grep -rqE '"/home/[a-z]+' "$PATHS_DIR"/*.sh 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

echo ""
echo "Paths templates tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
