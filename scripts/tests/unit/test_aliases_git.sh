#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for git aliases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/.chezmoitemplates/aliases/git"

test_start "git_aliases_dir_exists"
assert_dir_exists "$ALIASES_DIR" "git aliases directory should exist"

test_start "git_aliases_valid_syntax"
invalid=0
for f in "$ALIASES_DIR"/*.sh; do
  [[ -f "$f" ]] && ! bash -n "$f" 2>/dev/null && ((invalid++))
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all valid"
else
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid invalid"
fi

test_start "git_defines_aliases"
if grep -rq 'alias g' "$ALIASES_DIR" 2>/dev/null; then
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines git aliases"
else
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define aliases"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
