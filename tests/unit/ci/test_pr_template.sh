#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# The PR template is the workspace standard (~/Code/PR-TEMPLATE.md, synced
# into defaults/Code by standards-sync) followed by this repository's
# signature block, which .github/workflows/pr-signature.yml requires.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEMPLATE="$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
STANDARD="$REPO_ROOT/defaults/Code/PR-TEMPLATE.md"

test_start "one_pr_template"
# Counted in the index: on a case-insensitive filesystem the two spellings
# are one file on disk, while git (and GitHub) keep both.
count="$(git -C "$REPO_ROOT" ls-files .github | grep -c -i '^\.github/pull_request_template\.md$')"
assert_equals "1" "$count" "exactly one PR template, so GitHub cannot pick a stale copy"

test_start "pr_template_starts_with_the_standard"
standard_bytes="$(wc -c <"$STANDARD" | tr -d ' ')"
if head -c "$standard_bytes" "$TEMPLATE" | cmp -s - "$STANDARD"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: the template does not open with defaults/Code/PR-TEMPLATE.md"
fi

test_start "pr_template_ends_with_the_signature"
assert_equals "THE ARCHITECT ᛫ Sebastien Rousseau ᛫ https://sebastienrousseau.com" \
  "$(tail -n 2 "$TEMPLATE" | head -n 1)" "the architect line is second to last"
assert_equals "THE ENGINE ᛞ EUXIS ᛫ Enterprise Unified Execution Intelligence System ᛫ https://github.com/sebastienrousseau/euxis" \
  "$(tail -n 1 "$TEMPLATE")" "the engine line is last"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
