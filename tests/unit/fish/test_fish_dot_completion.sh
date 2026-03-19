#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/dot_config/fish/completions/dot.fish.tmpl"

test_start "fish_dot_completion_exists"
assert_file_exists "$TARGET" "fish dot completion should exist"

test_start "fish_dot_completion_version_entry"
assert_file_contains "$TARGET" '-a "version --version"' "fish completion exposes version and --version"

test_start "fish_dot_completion_mcp_flags"
assert_file_contains "$TARGET" '__fish_seen_subcommand_from mcp' "fish completion defines mcp flags"
assert_file_contains "$TARGET" '-s s -l strict' "fish completion exposes mcp --strict|-s"
assert_file_contains "$TARGET" '-s j -l json' "fish completion exposes mcp --json|-j"

test_start "fish_dot_completion_attest_flags"
assert_file_contains "$TARGET" '__fish_seen_subcommand_from attest' "fish completion defines attest flags"
assert_file_contains "$TARGET" '-s w -l write' "fish completion exposes attest --write|-w"

test_start "fish_dot_completion_restore_flags"
assert_file_contains "$TARGET" '__fish_seen_subcommand_from restore' "fish completion defines restore flags"
assert_file_contains "$TARGET" '-s L -l latest' "fish completion exposes restore --latest|-L"
assert_file_contains "$TARGET" '-s g -l git' "fish completion exposes restore --git|-g"
assert_file_contains "$TARGET" '-s d -l diff' "fish completion exposes restore --diff|-d"
assert_file_contains "$TARGET" '-s n -l dry-run' "fish completion exposes restore --dry-run|-n"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
