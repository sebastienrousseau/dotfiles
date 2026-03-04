#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/ops/bundle.sh"

test_start "bundle_exists"
assert_file_exists "$TEST_SCRIPT" "bundle.sh should exist"

test_start "bundle_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "bundle_uses_tar_zstd"
assert_file_contains "$TEST_SCRIPT" "tar --zstd" "should compress using tar and zstd"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
