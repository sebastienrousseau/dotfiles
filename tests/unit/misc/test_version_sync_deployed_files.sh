#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# version-sync must never rewrite the ~/Code workspace standards under
# defaults/Code/. They are deployed into $HOME, and their version strings
# (v0.0.1, v0.0.45, a GitHub release tag) are other projects' on purpose:
# the sync once stamped v0.2.530 over every one of them. Sources
# scripts/version-sync.sh (main does not run when sourced) in a subshell.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

excluded() {
  (
    source "$REPO_ROOT/scripts/version-sync.sh"
    is_excluded_file "$1" && echo yes || echo no
  )
}

test_start "version_sync_skips_the_deployed_workspace_standards"
assert_equals "yes" "$(excluded defaults/Code/AGENTS.md)" "defaults/Code/AGENTS.md is not rewritten"
assert_equals "yes" "$(excluded defaults/Code/README-TEMPLATE.md)" "the README template is not rewritten"

test_start "version_sync_still_rewrites_its_own_docs"
assert_equals "no" "$(excluded README.md)" "the repository README still follows the release"
assert_equals "no" "$(excluded defaults/Codex.md)" "a sibling path that only starts with Code is not skipped"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
