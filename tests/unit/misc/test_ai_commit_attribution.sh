#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HOOK="$REPO_ROOT/defaults/dot_config/git/hooks/executable_commit-msg"
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

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
