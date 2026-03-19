#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/dot_config/nushell/aliases.nu.tmpl"

test_start "nushell_core_parity_aliases"
assert_file_contains "$TARGET" "alias dm = dot mode list" "nushell exposes dm"
assert_file_contains "$TARGET" "alias da = dot agent list" "nushell exposes da"
assert_file_contains "$TARGET" "alias dmc = dot mcp registry" "nushell exposes dmc"
assert_file_contains "$TARGET" "alias datt = dot attest --json" "nushell exposes datt"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
