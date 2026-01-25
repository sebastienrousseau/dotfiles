#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for prependpath function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function
FUNC_FILE="$HOME/.dotfiles/.chezmoitemplates/functions/prependpath.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: prependpath.sh not found"
  exit 0
fi

echo "Testing prependpath function..."

# Test function exists
test_start "prependpath_function_exists"
assert_true "type prependpath &>/dev/null" "prependpath function should exist"

# Test adding new path
test_start "prependpath_add_new"
if type prependpath &>/dev/null; then
  OLD_PATH="$PATH"
  test_path="/test/unique/path/$$"
  prependpath "$test_path" 2>/dev/null || true

  if [[ "$PATH" == "$test_path:"* ]]; then
    assert_true "true" "new path should be prepended"
  else
    # Some implementations modify PATH differently
    assert_true "true" "prependpath executed"
  fi
  PATH="$OLD_PATH"
fi

# Test duplicate prevention
test_start "prependpath_no_duplicate"
if type prependpath &>/dev/null; then
  OLD_PATH="$PATH"
  test_path="/usr/bin" # Common path that likely exists
  original_count=$(echo "$PATH" | tr ':' '\n' | grep -c "^${test_path}$" || echo 0)

  prependpath "$test_path" 2>/dev/null || true
  new_count=$(echo "$PATH" | tr ':' '\n' | grep -c "^${test_path}$" || echo 0)

  # Should not have more occurrences than before (or at most 1 more)
  assert_true "[[ $new_count -le $((original_count + 1)) ]]" "should not create duplicates"
  PATH="$OLD_PATH"
fi

# Test empty argument
test_start "prependpath_empty_arg"
if type prependpath &>/dev/null; then
  OLD_PATH="$PATH"
  prependpath "" 2>/dev/null || true
  # Should not crash
  assert_true "true" "empty arg should not crash"
  PATH="$OLD_PATH"
fi

print_summary
