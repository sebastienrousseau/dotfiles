#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The claude-statusline registry module (plan P1.6): Claude Code runs it
# with the session as JSON on stdin, and it prints the model, the folder,
# dot's agent mode and the session's cost against the policy's budget.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
LINE="$REPO_ROOT/registry/modules/claude-statusline/files/dot_local/bin/executable_dot-claude-statusline"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-statusline.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
H="$WORK/home"
mkdir -p "$H/.config/dotfiles" "$WORK/jq"
ln -s "$(command -v jq)" "$WORK/jq/jq"
SESSION='{"session_id":"s1","model":{"display_name":"Opus"},"workspace":{"current_dir":"/src/acme"},"cost":{"total_cost_usd":1.234}}'

# line JSON [NAME=value...]: the status line for JSON in the sandboxed home;
# RC, OUT.
line() {
  local json="$1"
  shift
  RC=0
  OUT="$(printf '%s' "$json" | env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/jq:/usr/bin:/bin" NO_COLOR=1 "$@" \
    bash "$LINE" 2>&1)" || RC=$?
}

test_start "model_folder_and_cost_with_no_policy"
line "$SESSION"
assert_equals "0" "$RC" "exit 0"
assert_equals "Opus · acme · \$1.23" "$OUT" "no policy, no mode: model, folder, cost"

test_start "mode_from_the_state_file_and_the_budget"
printf 'schema = "ai-policy.v1"\ndefault_mode = "ask"\n\n[mode.ask]\ntools = ["read"]\n\n[budget]\ndaily_usd = 20\nsession_usd = 5\n' >"$H/.config/dotfiles/ai-policy.toml"
printf 'DOT_AGENT_PROFILE=plan\nDOT_AGENT_PROFILE=apply\n' >"$H/.config/dotfiles/agent-mode.env"
line "$SESSION"
assert_equals "Opus · acme · apply · \$1.23 of \$5.00" "$OUT" "the last mode set; the session budget"

test_start "the_environment_names_the_mode_first"
line "$SESSION" DOT_AGENT_PROFILE=audit
assert_equals "Opus · acme · audit · \$1.23 of \$5.00" "$OUT" "DOT_AGENT_PROFILE wins"

test_start "the_policy_default_mode_when_none_is_set"
rm -f "$H/.config/dotfiles/agent-mode.env"
line "$SESSION"
assert_equals "Opus · acme · ask · \$1.23 of \$5.00" "$OUT" "default_mode"

test_start "another_policy_file"
printf 'schema = "ai-policy.v1"\ndefault_mode = "plan"\n[mode.plan]\ntools = ["read"]\n' >"$WORK/other.toml"
line "$SESSION" DOT_AI_POLICY="$WORK/other.toml"
assert_equals "Opus · acme · plan · \$1.23" "$OUT" "DOT_AI_POLICY; no budget there"

test_start "the_budget_in_colour"
line "$SESSION" NO_COLOR=
assert_equals $'Opus · acme · ask · $1.23 of $5.00' "$OUT" "under 80%: no colour"
line '{"model":{"display_name":"Opus"},"cwd":"/w","cost":{"total_cost_usd":4.1}}' NO_COLOR=
assert_equals $'Opus · w · ask · \e[33m$4.10 of $5.00\e[0m' "$OUT" "from 80%: yellow"
line '{"model":{"display_name":"Opus"},"cwd":"/w","cost":{"total_cost_usd":5}}' NO_COLOR=
assert_equals $'Opus · w · ask · \e[31m$5.00 of $5.00\e[0m' "$OUT" "at 100%: red"

test_start "missing_fields_are_left_out"
line '{}'
assert_equals "ask" "$OUT" "only what is known"
line 'not json'
assert_equals "0" "$RC" "never fails: Claude Code would show the error"
assert_equals "ask" "$OUT" "input it cannot read is no session"

test_start "no_jq"
mkdir -p "$WORK/nojq"
RC=0
OUT="$(printf '%s' "$SESSION" | env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/nojq" "$(command -v bash)" "$LINE" 2>&1)" || RC=$?
assert_equals "0" "$RC" "exit 0"
assert_equals "dot status line: needs jq" "$OUT" "says so on the line"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
