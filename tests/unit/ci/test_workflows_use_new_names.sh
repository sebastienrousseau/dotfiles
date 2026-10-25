#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091
# Workflows run `dot` from the release being built. A removed name exits
# 127 there, as `dot registry` did in the v0.2.538 install smoke, so no
# workflow step may call one.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

echo "Testing that workflows call the new command names..."

test_start "no_workflow_step_calls_a_removed_name"
removed="$(awk -F'|' '$1 == "alias" && $3 == "removed" { print $2 }' \
  "$REPO_ROOT/lib/dot/data/commands.txt" | paste -sd'|' -)"
# A call is `dot`, `bin/dot` or `"$installed"` followed by the name;
# YAML comments are prose about the command, not a call to it.
hits="$(grep -rnE "(^|[ /\"(])(dot|\\\$installed|\\\$DOT_CLI)\"? (${removed})([ \"')]|$)" \
  "$REPO_ROOT/.github/workflows" "$REPO_ROOT/.github/actions" |
  grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)"
assert_equals "" "$hits" "workflow steps call removed names"

test_summary
