#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/dot_config/fish/functions/dot.fish"

test_start "fish_dot_enterprise_helpers"
assert_file_contains "$TARGET" "function dm" "fish exposes dm"
assert_file_contains "$TARGET" "function da" "fish exposes da"
assert_file_contains "$TARGET" "function dmc" "fish exposes dmc"
assert_file_contains "$TARGET" "function datt" "fish exposes datt"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
