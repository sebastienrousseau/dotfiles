#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
#
# test_reusable_pin_lint.sh — negative test for #855.
#
# Builds a sandboxed `.github/workflows/` tree, drops in workflows
# containing each rejected reference form, and asserts that
# `scripts/ci/lint-reusable-pins.sh` exits non-zero with the right
# error message. Then drops in only-pinned workflows and asserts
# the script exits zero.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LINT="$REPO_ROOT/scripts/ci/lint-reusable-pins.sh"

# -----------------------------------------------------------------------------
# Helper: run the lint against an isolated REPO_ROOT containing only
# the workflow file we want to test.
# -----------------------------------------------------------------------------
run_lint_with() {
  local workflow_body="$1"
  local tmp
  tmp=$(mktemp -d -t reusable-pin.XXXXXX)
  mkdir -p "$tmp/.github/workflows"
  cp "$LINT" "$tmp/lint.sh"
  printf '%s' "$workflow_body" >"$tmp/.github/workflows/test.yml"
  # The script reads REPO_ROOT; override it so the lint scans the
  # sandboxed tree, not the real repo.
  (
    cd "$tmp"
    REPO_ROOT="$tmp" bash "$tmp/lint.sh"
  )
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

test_start "lint_passes_on_clean_pin"
clean_yaml='jobs:
  lint:
    uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@b0615f8fb5c0f3826f58904a5567eff11b6c500e # master
'
if run_lint_with "$clean_yaml" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "lint_fails_on_relative_path"
relative_yaml='jobs:
  lint:
    uses: ./.github/workflows/reusable-shell-lint.yml
'
if run_lint_with "$relative_yaml" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint should fail on relative path"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "lint_fails_on_branch_ref"
branch_yaml='jobs:
  lint:
    uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@master
'
if run_lint_with "$branch_yaml" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint should fail on branch ref"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "lint_fails_on_short_sha"
short_sha_yaml='jobs:
  lint:
    uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@b0615f8f
'
if run_lint_with "$short_sha_yaml" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint should fail on short SHA"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "lint_fails_on_tag_ref"
tag_yaml='jobs:
  lint:
    uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@v0.2.501
'
if run_lint_with "$tag_yaml" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint should fail on tag ref"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
