#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# `dot system update` offers `dot cli hook install` once per machine, before
# its phases start (plugins/system/libexec/system/upgrade.sh
# _dot_upgrade_consent_hooks): only when an agent lacks the hook, only to
# someone who can answer (a terminal, or -y), and never again once answered.
# Codex is the agent here, so jq plays no part; the home is a sandbox.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hook-offer.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
H="$WORK/home"
MARKER="$H/.state/dot/cli/hook-offer.asked"

# offer [VAR=value...]: _dot_upgrade_consent_hooks in the sandboxed home,
# the question answered by ANSWER (0 yes, 1 no) when someone can answer
# (CAN_ASK=1); prints "<DOT_UPGRADE_HOOKS> <questions asked>".
offer() {
  env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$H/.state" "$@" bash -c '
    set -euo pipefail
    source "$1/plugins/system/libexec/system/upgrade.sh"
    asked=0 work="$2"
    dot_can_ask() { [[ "${CAN_ASK:-0}" == 1 ]]; }
    dot_consent() { asked=$((asked + 1)); echo "$1" >>"$work/questions"; [[ "${DOTFILES_YES:-0}" == 1 ]] || return "${ANSWER:-1}"; }
    _dot_upgrade_consent_hooks
    echo "$DOT_UPGRADE_HOOKS $asked"' _ "$REPO_ROOT" "$WORK"
}

test_start "an_unwired_agent_is_offered_and_yes_installs"
mkdir -p "$H/.codex"
assert_equals "1 1" "$(offer CAN_ASK=1 ANSWER=0)" "asked once, and yes sets the step"
assert_contains "from codex (dot cli hook install)" "$(cat "$WORK/questions")" "naming the agent"
assert_true "[[ -f '$MARKER' ]]" "the answer is remembered"

test_start "once_answered_it_is_not_asked_again"
assert_equals "0 0" "$(offer CAN_ASK=1 ANSWER=0)" "the marker stops a second question"

test_start "no_is_remembered_too"
rm -f "$MARKER"
assert_equals "0 1" "$(offer CAN_ASK=1 ANSWER=1)" "no leaves the hooks alone"
assert_true "[[ -f '$MARKER' ]]" "and is not asked again"

test_start "nobody_to_ask_means_no_question_and_no_marker"
rm -f "$MARKER"
assert_equals "0 0" "$(offer)" "an unattended run does not ask"
assert_false "[[ -f '$MARKER' ]]" "so the next run with a terminal still will"

test_start "yes_flag_answers"
assert_equals "1 1" "$(offer DOTFILES_YES=1)" "-y counts as consent"

test_start "a_wired_agent_is_not_offered"
rm -f "$MARKER"
printf 'notify = ["%s/bin/dot", "cli", "hook", "run", "--agent", "codex"]\n' "$(cd "$REPO_ROOT" && pwd)" >"$H/.codex/config.toml"
# Codex is wired once its hooks.json also runs the policy check (ADR-025).
jq -n --arg c "'$(cd "$REPO_ROOT" && pwd)/bin/dot' cli hook check --agent codex" \
  '{hooks: {PreToolUse: [{hooks: [{type: "command", command: $c}]}]}}' >"$H/.codex/hooks.json"
assert_equals "0 0" "$(offer CAN_ASK=1 ANSWER=0)" "nothing to wire, nothing asked"
assert_false "[[ -f '$MARKER' ]]" "and nothing remembered"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
