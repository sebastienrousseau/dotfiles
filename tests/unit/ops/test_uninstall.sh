#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091
# Unit tests for scripts/uninstall.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UNINSTALL_SCRIPT="$REPO_ROOT/scripts/uninstall.sh"

test_start "uninstall_script_exists"
assert_file_exists "$UNINSTALL_SCRIPT" "uninstall.sh should exist"

test_start "uninstall_syntax"
assert_exit_code 0 "bash -n '$UNINSTALL_SCRIPT'"

test_start "uninstall_has_shebang"
assert_file_contains "$UNINSTALL_SCRIPT" "#!/usr/bin/env bash" "should have bash shebang"

test_start "uninstall_has_force_flag"
assert_file_contains "$UNINSTALL_SCRIPT" '"--force"' "should support --force flag"

test_start "uninstall_purges_chezmoi"
assert_file_contains "$UNINSTALL_SCRIPT" "chezmoi purge" "should purge chezmoi-managed files"

test_start "uninstall_removes_dotfiles_repo"
assert_file_contains "$UNINSTALL_SCRIPT" 'rm -rf "$HOME/.dotfiles"' "should remove dotfiles repo"

test_start "uninstall_cleans_caches"
assert_file_contains "$UNINSTALL_SCRIPT" "dotfiles" "should clean dotfiles caches"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
