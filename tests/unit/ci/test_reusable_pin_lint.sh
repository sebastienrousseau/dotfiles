#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Contract tests for same-commit local reusable workflows and immutable
# external reusable-workflow references.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LINT="$REPO_ROOT/tools/ci/lint-reusable-pins.sh"

run_lint_with() {
  local workflow_body="$1"
  local tmp rc=0
  tmp=$(mktemp -d -t reusable-reference.XXXXXX)
  mkdir -p "$tmp/.github/workflows"
  printf '%s' "$workflow_body" >"$tmp/.github/workflows/test.yml"
  (
    cd "$tmp"
    REPO_ROOT="$tmp" GITHUB_REPOSITORY="sebastienrousseau/dotfiles" bash "$LINT"
  ) || rc=$?
  rm -rf "$tmp"
  return "$rc"
}

assert_lint_passes() {
  local body="$1" message="$2"
  if run_lint_with "$body" >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $message"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $message"
  fi
}

assert_lint_fails() {
  local body="$1" message="$2"
  if run_lint_with "$body" >/dev/null 2>&1; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $message"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $message"
  fi
}

test_start "lint_passes_on_same_repository_local_reference"
assert_lint_passes 'jobs:
  lint:
    uses: ./.github/workflows/reusable-shell-lint.yml
' "local reference executes the workflow from the commit under test"

test_start "lint_fails_on_same_repository_remote_sha"
assert_lint_fails 'jobs:
  lint:
    uses: sebastienrousseau/dotfiles/.github/workflows/reusable-shell-lint.yml@b0615f8fb5c0f3826f58904a5567eff11b6c500e
' "stale same-repository SHA cannot bypass PR workflow changes"

test_start "lint_passes_on_external_full_sha"
assert_lint_passes 'jobs:
  audit:
    uses: example/security-workflows/.github/workflows/audit.yml@b0615f8fb5c0f3826f58904a5567eff11b6c500e
' "external workflow is immutable"

test_start "lint_passes_on_exact_slsa_bootstrap_exception"
assert_lint_passes 'jobs:
  provenance:
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
' "SLSA bootstrap retains its required reviewed release tag"

test_start "lint_fails_on_external_branch_ref"
assert_lint_fails 'jobs:
  audit:
    uses: example/security-workflows/.github/workflows/audit.yml@main
' "external branch is mutable"

test_start "lint_fails_on_external_short_sha"
assert_lint_fails 'jobs:
  audit:
    uses: example/security-workflows/.github/workflows/audit.yml@b0615f8f
' "short SHA is not an immutable full identifier"

test_start "lint_fails_on_external_tag_ref"
assert_lint_fails 'jobs:
  audit:
    uses: example/security-workflows/.github/workflows/audit.yml@v1
' "external tag is mutable"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
