#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Guard: the deployed fish/nushell completion templates must stay generated
## from `dot completion` (single source of truth). Fails if bin/dot commands
## change without rerunning scripts/ops/gen-completions.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

GEN="$REPO_ROOT/scripts/ops/gen-completions.sh"

test_start "gen_completions_script_exists"
assert_file_exists "$GEN" "scripts/ops/gen-completions.sh should exist"

test_start "deployed_completions_in_sync_with_dot_completion"
assert_exit_code 0 "bash '$GEN' --check" "fish/nushell completions must match 'dot completion' output"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
