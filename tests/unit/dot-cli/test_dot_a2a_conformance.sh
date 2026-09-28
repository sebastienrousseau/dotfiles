#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# What the checker validates (each document, specVersion, skills, signing,
# the a2a-ready protocol) is asserted by running it against fixtures in
# tests/unit/diagnostics/test_a2a_conformance_fixtures.sh, and the
# `dot agent a2a-card` subcommand in test_dot_agent_a2a.sh. This file
# checks the shipped tree end to end.

CONFORMANCE_SCRIPT="$REPO_ROOT/scripts/diagnostics/a2a-conformance.sh"

test_start "conformance_script_exists"
assert_file_exists "$CONFORMANCE_SCRIPT" "a2a-conformance.sh should exist"

test_start "conformance_json_output"
output=$(REPO_ROOT="$REPO_ROOT" bash "$CONFORMANCE_SCRIPT" --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$(printf '%s' "$output" | jq -r '.specVersion')" == "0.3" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: JSON output includes specVersion 0.3"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: JSON output should include specVersion 0.3"
  printf '%b\n' "    Output: $output"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
