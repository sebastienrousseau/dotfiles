#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HOOK="${COMMIT_MSG_HOOK:-$REPO_ROOT/defaults/dot_config/git/hooks/executable_commit-msg}"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home"

test_start "commit_hook_attributes_codex_before_stale_claude_state"
codex_message="$SANDBOX/codex-message"
printf 'feat: test\n' >"$codex_message"
env -i PATH="$PATH" HOME="$SANDBOX/home" CODEX_SESSION_ID=test CLAUDECODE=1 \
  CODEX_MODEL=gpt-test bash "$HOOK" "$codex_message"
assert_file_contains "$codex_message" "Assisted-by: Codex:gpt-test" \
  "Codex session receives exact attribution"
assert_equals "0" "$(grep -c '^Assisted-by: Claude:' "$codex_message" || true)" \
  "stale Claude state does not override Codex"

test_start "commit_hook_attributes_gemini"
gemini_message="$SANDBOX/gemini-message"
printf 'feat: test\n' >"$gemini_message"
env -i PATH="$PATH" HOME="$SANDBOX/home" GEMINI_SESSION_ID=test \
  GEMINI_MODEL=gemini-test bash "$HOOK" "$gemini_message"
assert_file_contains "$gemini_message" "Assisted-by: Gemini:gemini-test" \
  "Gemini session receives exact attribution"

test_start "commit_hook_joins_the_existing_trailer_block"
signed_message="$SANDBOX/signed-message"
printf 'feat: test\n\nBody.\n\nSigned-off-by: A U Thor <a@example.com>\n' >"$signed_message"
env -i PATH="$PATH" HOME="$SANDBOX/home" CLAUDECODE=1 \
  ANTHROPIC_MODEL=claude-test bash "$HOOK" "$signed_message"
# git reads trailers from the last paragraph only, so Assisted-by must land
# in the same block as Signed-off-by, not in a paragraph of its own.
signed_trailers="$(git interpret-trailers --parse <"$signed_message")"
assert_contains "Signed-off-by: A U Thor <a@example.com>" "$signed_trailers" \
  "the sign-off stays a parsed trailer"
assert_contains "Assisted-by: Claude:" "$signed_trailers" \
  "Assisted-by joins the sign-off's trailer block"

test_start "commit_hook_starts_a_trailer_block_when_none_exists"
plain_message="$SANDBOX/plain-message"
printf 'feat: test\n\nBody text only.\n' >"$plain_message"
env -i PATH="$PATH" HOME="$SANDBOX/home" CLAUDECODE=1 \
  ANTHROPIC_MODEL=claude-test bash "$HOOK" "$plain_message"
assert_contains "Assisted-by: Claude:" "$(git interpret-trailers --parse <"$plain_message")" \
  "Assisted-by is a parsed trailer on a message without one"
assert_file_contains "$plain_message" "Body text only." "the body is kept"

# Only the committing process's own environment counts: a claude process
# running elsewhere, or an API key exported in the shell, is not a session.
mkdir -p "$SANDBOX/bin"
printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/bin/pgrep"
chmod +x "$SANDBOX/bin/pgrep"

test_start "commit_hook_ignores_a_claude_process_elsewhere"
hand_message="$SANDBOX/hand-message"
printf 'feat: test\n' >"$hand_message"
env -i PATH="$SANDBOX/bin:$PATH" HOME="$SANDBOX/home" bash "$HOOK" "$hand_message"
assert_equals "0" "$(grep -c '^Assisted-by:' "$hand_message" || true)" \
  "a running claude process elsewhere does not attribute a hand-written commit"

test_start "commit_hook_ignores_an_exported_api_key"
key_message="$SANDBOX/key-message"
printf 'feat: test\n' >"$key_message"
env -i PATH="$PATH" HOME="$SANDBOX/home" ANTHROPIC_API_KEY=sk-test bash "$HOOK" "$key_message"
assert_equals "0" "$(grep -c '^Assisted-by:' "$key_message" || true)" \
  "ANTHROPIC_API_KEY alone is not an agent session"

test_start "commit_hook_attributes_claude_session_with_model_override"
session_message="$SANDBOX/session-message"
printf 'feat: test\n' >"$session_message"
env -i PATH="$PATH" HOME="$SANDBOX/home" CLAUDE_CODE_SESSION_ID=abc CLAUDE_MODEL=claude-test \
  bash "$HOOK" "$session_message"
assert_file_contains "$session_message" "Assisted-by: Claude:claude-test" \
  "a Claude Code session variable attributes the commit, with CLAUDE_MODEL"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
