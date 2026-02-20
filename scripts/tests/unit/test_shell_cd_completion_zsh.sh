#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Tests for zsh bookmark completion setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

COMPLETION_FILE="$REPO_ROOT/.chezmoitemplates/aliases/cd/cd-completion.aliases.sh"

test_start "zsh_completion_file_exists"
assert_file_exists "$COMPLETION_FILE" "cd completion template should exist"

if command -v zsh >/dev/null 2>&1; then
  tmp_bookmarks="$(mktemp)"
  printf "proj:%s\nwork:%s\n" "$HOME" "$HOME" > "$tmp_bookmarks"

  test_start "zsh_completion_source"
  assert_exit_code 0 "zsh -c 'set -e; autoload -U compinit; compinit; BOOKMARK_FILE=\"$tmp_bookmarks\"; source \"$COMPLETION_FILE\"; typeset -f _bookmark_complete_zsh >/dev/null'"

  rm -f "$tmp_bookmarks"
else
  test_start "zsh_completion_source"
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: zsh not available, skipped"
fi

echo ""
echo "CD completion zsh tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
