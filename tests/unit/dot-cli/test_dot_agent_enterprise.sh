#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
META_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"
AGENT_CARD="$REPO_ROOT/dot_config/dotfiles/agent-card.json"
WELL_KNOWN="$REPO_ROOT/.well-known/agent.json"

test_start "agent_card_exists"
assert_file_exists "$AGENT_CARD" "agent-card.json should exist"
assert_file_exists "$WELL_KNOWN" ".well-known agent.json should exist"

test_start "agent_meta_supports_card_and_log"
assert_file_contains "$META_FILE" "card)" "dot mode supports card"
assert_file_contains "$META_FILE" "log)" "dot mode supports log"

test_start "agent_card_runs"
assert_output_contains "Agent Card" "bash '$DOT_CLI' agent card"

test_start "agent_card_json_runs"
output=$(bash "$DOT_CLI" agent card --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"protocols\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: emits agent card JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should emit agent card JSON"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
