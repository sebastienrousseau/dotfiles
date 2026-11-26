#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1091
# macOS before 27 ships no timeout(1), and the macOS runners do not install
# coreutils. Shipped code that calls `timeout <secs> <cmd>` without first
# checking for it fails there with 127, and an error discarded with
# `2>/dev/null || true` hides that: the SSH key was never added, `/vibe`
# never ran its delegate. Shipped code bounds a command with dot_bounded or
# dot_probe (lib/dot/probe.sh), or checks for timeout(1) and falls back.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# A call: `timeout`, optional flags, then a duration, at the start of a
# command. Comments and strings that merely mention the word do not match.
CALL='(^|[;&|({]|\$\(|then|do|else|exec|!)[[:space:]]*timeout([[:space:]]+-[-a-z=0-9]+)*[[:space:]]+["$0-9]'
# A check for it: `command -v timeout`, `type -P timeout`, or zsh's
# `${+commands[timeout]}`.
GUARD='command -v timeout|type -P timeout|commands\[timeout\]'

test_start "shipped_timeout_calls_are_guarded"
unguarded=""
while IFS= read -r file; do
  grep -Eq "$GUARD" "$REPO_ROOT/$file" || unguarded+=" $file"
done < <(cd "$REPO_ROOT" && git grep -l -E "$CALL" -- \
  bin lib plugins scripts defaults benches install.sh ':!*.md')
if [[ -z "$unguarded" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: timeout(1) called with no check for it in:$unguarded"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
