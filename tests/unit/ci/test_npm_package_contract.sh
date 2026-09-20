#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

test_start "npm_package_has_both_license_grants"
assert_file_contains "$REPO_ROOT/package.json" '"LICENSE-APACHE"' "Apache license is packaged"
assert_file_contains "$REPO_ROOT/package.json" '"LICENSE-MIT"' "MIT license is packaged"

test_start "npm_package_contains_verified_chezmoi_bootstrap"
assert_file_contains "$REPO_ROOT/package.json" '"tools/ci/install-chezmoi-verified.sh"' "installer dependency is packaged"

test_start "npm_package_excludes_repository_payload"
assert_output_not_contains '"scripts/"' "cat '$REPO_ROOT/package.json'"
assert_output_not_contains '"defaults/"' "cat '$REPO_ROOT/package.json'"

test_start "npm_pack_matches_allowlist"
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  assert_exit_code 0 "cd '$REPO_ROOT' && node scripts/qa/verify-npm-package.mjs"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (node/npm unavailable)"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
