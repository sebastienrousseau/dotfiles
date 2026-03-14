#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091
# Property-based tests for path handling via prependpath

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/property_testing.sh"

# Source the function under test
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/misc/prependpath.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: prependpath.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

echo "Property tests for path handling (prependpath)..."

# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------

# Generate safe path-like strings using the framework's generate_path helper
gen_safe_path() {
  echo "/$(generate_path 3)"
}

# Generate paths with a leading slash and varying component counts
gen_abs_path() {
  local parts
  parts=$(generate_int 1 5)
  echo "/$(generate_path "$parts")"
}

# Generate edge-case strings that PATH handling must survive without corruption
# (uses only the safe subset of generate_edge_string — no shell metacharacters
#  that would break PATH colon-parsing)
gen_path_edge_case() {
  local safe_edges=(
    "/tmp/test-path"
    "/usr/local/bin"
    "/home/user/.local/bin"
    "/opt/custom/bin"
    "/very/deep/nested/directory/path"
    "/path-with-dash"
    "/path_with_underscore"
    "/path.with.dots"
    "/PATH/UPPER/CASE"
    "/123/numeric/start"
  )
  local idx
  idx=$(random_int $((${#safe_edges[@]} - 1)))
  echo "${safe_edges[$idx]}"
}

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

# Property 1: prependpath does not corrupt PATH — PATH remains colon-separated
# and all original entries survive
prop_path_not_corrupted() {
  local new_path="$1"
  local original_path="$PATH"

  # Run prependpath in a subshell-safe way by capturing updated PATH
  local updated_path
  updated_path=$(
    PATH="$original_path"
    prependpath "$new_path" 2>/dev/null
    echo "$PATH"
  )

  # Verify every component of the original PATH appears in the updated PATH
  # (PATH was only modified inside the subshell above, so the parent is unaffected)
  local IFS=':'
  local component
  for component in $original_path; do
    if [[ ":${updated_path}:" != *":${component}:"* ]]; then
      echo "PATH corrupted: original component '$component' missing from updated PATH"
      echo "  original: $original_path"
      echo "  updated:  $updated_path"
      return 1
    fi
  done

  return 0
}

# Property 2: prependpath is idempotent — calling it twice with the same path
# does not add duplicates
prop_prependpath_idempotent() {
  local new_path="$1"
  local base_path="/usr/bin:/usr/local/bin:/bin"

  local after_first after_second
  after_first=$(
    PATH="$base_path"
    prependpath "$new_path" 2>/dev/null
    echo "$PATH"
  )
  after_second=$(
    PATH="$after_first"
    prependpath "$new_path" 2>/dev/null
    echo "$PATH"
  )

  if [[ "$after_first" == "$after_second" ]]; then
    return 0
  else
    echo "Idempotency violated for '$new_path':"
    echo "  after first:  $after_first"
    echo "  after second: $after_second"
    return 1
  fi
}

# Property 3: when the path is new (not already in PATH), it appears
# at the front after prependpath
prop_new_path_at_front() {
  local new_path="$1"
  local base_path="/usr/bin:/usr/local/bin:/bin"

  # Ensure the new_path is not already in the base PATH
  if [[ ":${base_path}:" == *":${new_path}:"* ]]; then
    # Skip inputs already present — property doesn't apply
    return 0
  fi

  local updated_path
  updated_path=$(
    PATH="$base_path"
    prependpath "$new_path" 2>/dev/null
    echo "$PATH"
  )

  if [[ "$updated_path" == "${new_path}:"* ]]; then
    return 0
  else
    echo "New path not at front for '$new_path':"
    echo "  updated PATH: $updated_path"
    return 1
  fi
}

# Property 4: PATH length only grows or stays same — never shrinks after prepend
prop_path_monotone_length() {
  local new_path="$1"
  local base_path="/usr/bin:/usr/local/bin:/bin"
  local original_len updated_len

  original_len=${#base_path}

  local updated_path
  updated_path=$(
    PATH="$base_path"
    prependpath "$new_path" 2>/dev/null
    echo "$PATH"
  )

  updated_len=${#updated_path}

  if [[ "$updated_len" -ge "$original_len" ]]; then
    return 0
  else
    echo "PATH shrank after prepend: before=$original_len after=$updated_len"
    echo "  base:    $base_path"
    echo "  updated: $updated_path"
    return 1
  fi
}

# Property 5: prependpath handles edge case inputs without crashing
# (PATH should remain a valid string — not empty, not null)
prop_survives_edge_inputs() {
  local edge_input="$1"
  local base_path="/usr/bin:/bin"
  local result_path

  result_path=$(
    PATH="$base_path"
    # prependpath modifies PATH in place; we must handle failures gracefully
    prependpath "$edge_input" 2>/dev/null || true
    echo "$PATH"
  )

  # The key invariant: PATH must never become empty after any prependpath call
  if [[ -n "$result_path" ]]; then
    return 0
  else
    echo "PATH became empty after prependpath '$edge_input'"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Run property tests
# ---------------------------------------------------------------------------

test_start "prop_path_not_corrupted_safe_paths"
run_property_test \
  "prependpath does not corrupt existing PATH entries (safe paths)" \
  prop_path_not_corrupted \
  gen_safe_path \
  30

test_start "prop_path_idempotent"
run_property_test \
  "prependpath is idempotent — double call produces no duplicates" \
  prop_prependpath_idempotent \
  gen_abs_path \
  30

test_start "prop_new_path_prepended_at_front"
run_property_test \
  "new path appears at the front of PATH after prependpath" \
  prop_new_path_at_front \
  gen_safe_path \
  30

test_start "prop_path_length_monotone"
run_property_test \
  "PATH length never shrinks after prependpath" \
  prop_path_monotone_length \
  gen_abs_path \
  30

test_start "prop_path_survives_edge_inputs"
run_property_test \
  "prependpath survives edge-case path strings without corrupting PATH" \
  prop_survives_edge_inputs \
  gen_path_edge_case \
  20

echo ""
echo "path_safety property tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
