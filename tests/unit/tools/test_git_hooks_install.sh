#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# scripts/git-hooks/install.sh actually installing hooks.
#
# The script copies three hooks into <repo>/.git/hooks, where <repo> is
# derived from its own location. Running it from the checkout would rewrite
# the developer's live hooks, so no suite had ever run it past its first
# line. It is run here from a fixture repository instead: the script is
# symlinked in, so `dirname "${BASH_SOURCE[0]}"/../..` lands on the fixture
# and every write goes there.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

INSTALLER="$REPO_ROOT/scripts/git-hooks/install.sh"

# Not removed on exit: the coverage aggregator resolves the symlinked script
# after the whole sweep has finished, and a deleted fixture would resolve to
# nothing. The path is fixed and rebuilt on the next run.
FX="${TMPDIR:-/tmp}"
FX="${FX%/}/dot-cov-fixtures/git-hooks-install"
rm -rf "$FX"
mkdir -p "$FX/scripts/git-hooks" "$FX/.git/hooks"
ln -s "$INSTALLER" "$FX/scripts/git-hooks/install.sh"
for hook in pre-commit pre-push prepare-commit-msg; do
  printf '#!/bin/sh\n# fixture %s hook\nexit 0\n' "$hook" >"$FX/scripts/git-hooks/$hook"
done

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

test_start "git_hooks_install_installs_every_hook"
rc=0
out="$(cd "$FX" && "${BASH:-bash}" scripts/git-hooks/install.sh 2>&1)" || rc=$?
assert_equals "0" "$rc" "installing into a clean repository should exit 0"
assert_file_exists "$FX/.git/hooks/pre-commit" "pre-commit should be installed"
assert_file_exists "$FX/.git/hooks/pre-push" "pre-push should be installed"
assert_file_exists "$FX/.git/hooks/prepare-commit-msg" \
  "prepare-commit-msg should be installed"

test_start "git_hooks_install_reports_what_it_installed"
assert_contains "Installed pre-commit hook" "$out" "pre-commit should be reported"
assert_contains "Installed pre-push hook" "$out" "pre-push should be reported"
assert_contains "Installed prepare-commit-msg hook" "$out" \
  "prepare-commit-msg should be reported"

test_start "git_hooks_install_makes_the_hooks_executable"
assert_true "[[ -x '$FX/.git/hooks/pre-commit' ]]" \
  "an installed hook git cannot execute is not installed"

test_start "git_hooks_install_is_idempotent"
rc=0
(cd "$FX" && "${BASH:-bash}" scripts/git-hooks/install.sh >/dev/null 2>&1) || rc=$?
assert_equals "0" "$rc" "re-running over existing hooks should still exit 0"

print_summary
