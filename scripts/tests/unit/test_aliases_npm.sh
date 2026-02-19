#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/.chezmoitemplates/aliases/npm"

test_start "npm_aliases_exists"
assert_dir_exists "$ALIASES_DIR" "npm aliases should exist"

test_start "npm_aliases_valid"
invalid=0
for f in "$ALIASES_DIR"/*.sh; do [[ -f "$f" ]] && ! bash -n "$f" 2>/dev/null && ((invalid++)); done
[[ "$invalid" -eq 0 ]] && { ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"; } || { ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST"; }

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
