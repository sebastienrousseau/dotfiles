#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for alias templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

ALIASES_DIR="$REPO_ROOT/.chezmoitemplates/aliases"

# Test: aliases directory exists
test_start "aliases_dir_exists"
assert_dir_exists "$ALIASES_DIR" "aliases directory should exist"

# Test: count alias files
test_start "aliases_file_count"
count=$(find "$ALIASES_DIR" -name "*.sh" 2>/dev/null | wc -l)
if [[ "$count" -gt 10 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: found $count alias files"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: expected >10 alias files, found $count"
fi

# Test: all alias files have valid syntax
test_start "aliases_all_valid_syntax"
invalid=0
for script in $(find "$ALIASES_DIR" -name "*.sh" 2>/dev/null); do
  if ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all alias files valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid files invalid"
fi

# Test: aliases use proper guards
test_start "aliases_command_guards"
guarded=0
total=0
for script in $(find "$ALIASES_DIR" -name "*.sh" 2>/dev/null | head -20); do
  ((total++))
  if grep -qE 'command -v|which|type -p' "$script" 2>/dev/null; then
    ((guarded++))
  fi
done
if [[ "$guarded" -gt 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $guarded/$total use command guards"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: only $guarded/$total use guards"
fi

# Test: no dangerous aliases
test_start "aliases_no_dangerous"
dangerous=$(grep -rlE '(^|[;&[:space:]])(sudo[[:space:]]+)?rm[[:space:]]+-rf[[:space:]]+/($|[[:space:];])' "$ALIASES_DIR" 2>/dev/null | wc -l)
if [[ "$dangerous" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous aliases"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $dangerous files have dangerous aliases"
fi

# Test: docker aliases exist
test_start "aliases_docker_exists"
if [[ -d "$ALIASES_DIR/docker" ]] || [[ -f "$ALIASES_DIR/docker.aliases.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: docker aliases exist"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: docker aliases should exist"
fi

# Test: git aliases exist
test_start "aliases_git_exists"
if find "$ALIASES_DIR" -name "*git*" 2>/dev/null | grep -q .; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: git aliases exist"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: git aliases should exist"
fi

echo ""
echo "Aliases templates tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
