#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# `mise use -g npm:@charmland/crush` runs an install script that unpacks its
# download into archive-XXXXXX in the *current* directory. Run from the
# dotfiles checkout, that left dozens of 27 MB dirs in the repo root, so
# global installs run from a private scratch directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t ai-scratch.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/cwd" "$WORK/tmp"

# mise stub: behaves like crush's installer and litters the cwd.
cat >"$WORK/stubs/mise" <<STUB
#!/bin/sh
mkdir -p "archive-TEST" && echo "\$PWD" >"$WORK/mise-cwd"
exit "\${MISE_STUB_RC:-0}"
STUB
chmod +x "$WORK/stubs/mise"

run_helper() {
  (
    cd "$WORK/cwd" || exit 1
    TMPDIR="$WORK/tmp" PATH="$WORK/stubs:$PATH" bash -c '
      source "$1/lib/dot/ai-install.sh"
      _ai_in_scratch_dir mise use -g "npm:@charmland/crush@latest"
    ' _ "$REPO_ROOT"
  )
}

test_start "ai_install_leaves_cwd_clean"
run_helper
assert_dir_not_exists "$WORK/cwd/archive-TEST" "the caller's directory is not littered"

test_start "ai_install_runs_elsewhere"
assert_not_equals "$WORK/cwd" "$(cat "$WORK/mise-cwd" 2>/dev/null)" "mise ran outside the caller's directory"

test_start "ai_install_scratch_removed"
assert_equals "" "$(ls -A "$WORK/tmp")" "the scratch directory is removed"

test_start "ai_install_propagates_failure"
MISE_STUB_RC=7 run_helper
assert_equals "7" "$?" "the install's exit status is returned"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
