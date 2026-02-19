#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/.chezmoitemplates/aliases/macOS"

test_start "alias_dir_exists"
assert_dir_exists "$ALIASES_DIR" "aliases directory should exist"

test_start "alias_files_valid"
invalid=0
shopt -s nullglob
for f in "$ALIASES_DIR"/*.sh; do
  [[ -f "$f" ]] && ! bash -n "$f" 2>/dev/null && ((invalid++))
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all valid"
else
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid invalid"
fi

test_start "alias_no_hardcoded_paths"
if grep -rqE '"/home/[a-z]+' "$ALIASES_DIR" 2>/dev/null; then
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST"
else
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
