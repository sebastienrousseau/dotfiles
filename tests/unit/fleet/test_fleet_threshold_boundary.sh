#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Boundary of the `dot fleet drift predict` heuristic: a file is flagged
# "Likely to drift" when its recent drift count is >= the threshold (5).
# Found by mutation testing (F4: `-ge` -> `-gt` survived because the
# existing predict case used 6 and 1 occurrences, never exactly 5).
# Pinned here:
#   - count == threshold (5) is flagged
#   - count == threshold - 1 (4) is not flagged
# The history file lives under a sandboxed XDG_STATE_HOME; nothing
# touches the real HOME or the network.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FLEET="$REPO_ROOT/scripts/dot/commands/fleet.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
TMP="$DOTFILES_COV_TMPDIR"
[[ -n "$TMP" && -d "$TMP" ]] || {
  echo "sandbox tmpdir missing; refusing to run" >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: jq is required by drift predict"
  echo ""
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

STATE_DIR="$XDG_STATE_HOME/dotfiles/fleet"
HISTORY="$STATE_DIR/drift-history.jsonl"
mkdir -p "$STATE_DIR"

# history_with <file> <n> — n drifted entries naming <file>.
history_with() {
  local file="$1" n="$2" i
  : >"$HISTORY"
  for ((i = 0; i < n; i++)); do
    printf '{"time":"t","status":"drifted","files":["%s"]}\n' "$file" >>"$HISTORY"
  done
}

predict() {
  bash "$FLEET" fleet drift predict 2>&1 </dev/null
}

test_start "predict_flags_file_at_exactly_the_threshold"
history_with ".at-threshold" 5
out="$(predict)"
rc=$?
assert_equals 0 "$rc" "predict exits 0"
assert_contains "Likely to drift" "$out" "a file drifted exactly 5 times is flagged"
assert_contains ".at-threshold (drifted 5 times recently)" "$out" "count reported at the boundary"

test_start "predict_does_not_flag_file_one_below_the_threshold"
history_with ".below-threshold" 4
out="$(predict)"
rc=$?
assert_equals 0 "$rc" "predict exits 0"
if [[ "$out" == *"Likely to drift"* ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: a file drifted 4 times must not be flagged"
  printf '%s\n' "$out" | sed 's/^/    /'
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: a file drifted 4 times is not flagged"
fi
assert_contains "4 checks recorded" "$out" "total checks reported"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
