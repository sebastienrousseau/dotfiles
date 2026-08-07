#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

workflow="$REPO_ROOT/.github/workflows/mirror-main-to-master.yml"

test_start "master_mirror_workflow_exists"
assert_file_exists "$workflow" "compatibility mirror workflow exists"

test_start "master_mirror_only_follows_main"
assert_file_contains "$workflow" "branches: [main]" "mirror is triggered only by main"

test_start "master_mirror_is_non_destructive"
if grep -Fq -- "--force" "$workflow"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: mirror must never force-push master"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: mirror never force-pushes master"
fi

test_start "master_mirror_verifies_exact_sha"
# shellcheck disable=SC2016
assert_file_contains "$workflow" 'mirrored_sha" != "$GITHUB_SHA' "mirror verifies master matches the triggering main SHA"

test_start "master_mirror_documents_permanent_compatibility"
assert_file_contains "$workflow" "permanent compatibility redirect" "master is retained only for legacy raw URLs"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
