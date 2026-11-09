#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot cli hook check (plugins/cli/libexec/hook-check.sh, ADR-025): the
# policy hook, through bin/dot in a sandboxed home. No policy allows at
# once; a policy without dot-policy denies (fail closed); otherwise
# dot-policy decides, built from defaults/dot_local/share/dot-policy when
# Go is installed. dot cli hook install wires it on each agent's pre-tool
# event, and remove takes it out.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hook-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
JQ_DIR="$(dirname "$(command -v jq)")"
H="$WORK/home"
mkdir -p "$H/.config/dotfiles" "$H/bin"
POLICY="$H/.config/dotfiles/ai-policy.toml"
WRITE='{"tool_name":"Write","tool_input":{"file_path":"/w/a"},"cwd":"/w"}'

# check STDIN ARGS...: `dot cli hook check ARGS...` with STDIN; sets RC
# and OUT, its stdout (what the agent reads). Extra NAME=value pairs go in E.
E=()
check() {
  RC=0
  OUT="$(printf '%s' "$1" | env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$JQ_DIR:/usr/bin:/bin" \
    NO_COLOR=1 TERM=dumb ${E[@]+"${E[@]}"} bash "$REPO_ROOT/bin/dot" cli hook check "${@:2}" 2>/dev/null)" || RC=$?
}

# reason: the deny reason in OUT, from either protocol; empty on no deny.
reason() {
  jq -r 'if .decision == "deny" then .reason
    elif .hookSpecificOutput.permissionDecision == "deny" and .hookSpecificOutput.hookEventName == "PreToolUse"
    then .hookSpecificOutput.permissionDecisionReason else empty end' <<<"$OUT" 2>/dev/null
}

# form: which protocol OUT's denial is in, gemini or pretooluse.
form() {
  jq -r 'if has("decision") then "gemini" elif has("hookSpecificOutput") then "pretooluse" else "none" end' <<<"$OUT" 2>/dev/null
}

test_start "no_policy_allows_at_once"
check "$WRITE" --agent claude
assert_equals "0|" "$RC|$OUT" "claude: exit 0, nothing printed"
check "$WRITE" --agent gemini
assert_equals "0|{}" "$RC|$OUT" "gemini: {}"
check "$WRITE"
assert_equals "0|" "$RC|$OUT" "no --agent is claude"

test_start "a_policy_without_dot_policy_denies"
printf 'schema = "ai-policy.v1"\n' >"$POLICY"
E=(DOT_POLICY_BIN="$H/bin/none")
check "$WRITE" --agent claude
assert_equals "0" "$RC" "exit 0"
assert_contains "dot-policy is missing or failed" "$(reason)" "claude: a PreToolUse deny says why"
assert_equals "pretooluse" "$(form)" "in the PreToolUse form"
check "$WRITE" --agent codex
assert_contains "every tool call is denied" "$(reason)" "codex reads the same form"
assert_equals "pretooluse" "$(form)" "the PreToolUse one"
check "$WRITE" --agent gemini
assert_contains "dot-policy is missing or failed" "$(reason)" "gemini: decision deny"
assert_equals "gemini" "$(form)" "in Gemini CLI's own form"

test_start "a_dot_policy_that_cannot_run_denies"
printf 'not a program\n' >"$H/bin/broken"
chmod +x "$H/bin/broken"
E=(DOT_POLICY_BIN="$H/bin/broken")
check "$WRITE" --agent claude
assert_equals "0" "$RC" "exit 0 though it failed"
assert_contains "dot-policy is missing or failed" "$(reason)" "and the call is denied"

cat >"$H/bin/crash" <<'EOF'
#!/bin/sh
printf '{"partial\n'
exit 3
EOF
chmod +x "$H/bin/crash"
E=(DOT_POLICY_BIN="$H/bin/crash")
check "$WRITE" --agent claude
assert_contains "dot-policy is missing or failed" "$(reason)" "a crash is a denial"
assert_false "[[ '$OUT' == *partial* ]]" "and its half output is dropped"

test_start "a_quote_in_the_path_stays_valid_json"
Q="$H/we\"ird\\dir/ai-policy.toml"
mkdir -p "$(dirname "$Q")"
: >"$Q"
E=(DOT_POLICY_BIN="$H/bin/none" DOT_AI_POLICY="$Q")
check "$WRITE" --agent gemini
assert_contains "$Q is set" "$(reason)" "gemini: the path survives escaping"
check "$WRITE" --agent claude
assert_contains "$Q is set" "$(reason)" "claude too"

test_start "dot_policy_gets_the_call_and_the_policy"
cat >"$H/bin/fake" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >"$H/args"
cat >"$H/stdin"
printf 'VERDICT\n'
EOF
chmod +x "$H/bin/fake"
E=(DOT_POLICY_BIN="$H/bin/fake" XDG_CONFIG_HOME="$H/.config")
check "$WRITE" --agent codex
assert_equals "0|VERDICT" "$RC|$OUT" "its verdict is the hook's"
assert_equals "check --agent codex --policy $POLICY" "$(cat "$H/args")" "the agent and policy are passed"
assert_equals "$WRITE" "$(cat "$H/stdin")" "the call reaches its stdin"

test_start "end_to_end_with_dot_policy"
if ! command -v go >/dev/null 2>&1; then
  echo "  go unavailable: end-to-end skipped"
else
  (cd "$REPO_ROOT/defaults/dot_local/share/dot-policy" && GOFLAGS=-mod=mod go build -o "$H/bin/dot-policy" .) 2>/dev/null
  cat >"$POLICY" <<'EOF'
schema = "ai-policy.v1"
default_mode = "ask"
[mode.ask]
tools = ["read"]
EOF
  E=(DOT_POLICY_BIN="$H/bin/dot-policy")
  check "$WRITE" --agent claude
  assert_contains "(mode ask): tool Write (write) is not allowed" "$(reason)" "a write in ask mode is denied"
  check '{"tool_name":"Read","tool_input":{"file_path":"/w/a"},"cwd":"/w"}' --agent claude
  assert_equals "0|" "$RC|$OUT" "a read is allowed"
  E=(DOT_POLICY_BIN="$H/bin/dot-policy" DOT_AGENT_PROFILE=apply)
  check "$WRITE" --agent gemini
  assert_contains 'mode "apply" has no rules' "$(reason)" "an undefined mode fails closed"
fi

# install ARGS...: dot cli hook ARGS... in a home with every agent.
hook() {
  env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$JQ_DIR:/usr/bin:/bin" NO_COLOR=1 TERM=dumb \
    bash "$REPO_ROOT/bin/dot" cli hook "$@" >/dev/null 2>&1
}

test_start "install_wires_the_check_on_each_pre_tool_event"
mkdir -p "$H/.claude" "$H/.gemini" "$H/.codex"
hook install
assert_contains "cli hook check --agent claude" \
  "$(jq -r '.hooks.PreToolUse[].hooks[].command' "$H/.claude/settings.json")" "claude: PreToolUse"
assert_equals "dot-cli-hook-check" \
  "$(jq -r '.hooks.BeforeTool[].hooks[] | select(.command | contains("hook check --agent gemini")) | .name' "$H/.gemini/settings.json")" \
  "gemini: BeforeTool, named"
assert_contains "cli hook check --agent codex" \
  "$(jq -r '.hooks.PreToolUse[].hooks[].command' "$H/.codex/hooks.json")" "codex: hooks.json PreToolUse"
hook install
assert_equals "1" "$(jq '[.hooks.PreToolUse[].hooks[] | select(.command | contains("hook check"))] | length' "$H/.claude/settings.json")" \
  "a second install replaces, never doubles"

test_start "remove_takes_the_check_out"
hook remove
assert_equals "null|null" \
  "$(jq -c '.hooks' "$H/.claude/settings.json")|$(jq -c '.hooks' "$H/.codex/hooks.json")" "claude and codex hooks gone"
assert_equals "null" "$(jq -c '.hooks' "$H/.gemini/settings.json")" "gemini too"

test_start "check_skips_the_dispatcher"
# A dot with no lib/dot: only the fast path in bin/dot can answer.
T="$WORK/tree"
mkdir -p "$T/bin" "$T/plugins/cli"
cp "$REPO_ROOT/bin/dot" "$T/bin/dot"
cp -R "$REPO_ROOT/plugins/cli/libexec" "$T/plugins/cli/libexec"
OUT="$(printf '%s' "$WRITE" | env -i HOME="$H" PATH="/usr/bin:/bin" DOT_POLICY_BIN="$H/bin/none" \
  bash "$T/bin/dot" cli hook check --agent claude 2>/dev/null)"
assert_contains "dot-policy is missing or failed" "$(reason)" "the hook answered without the dispatcher"
RC=0
OUT="$(env -i HOME="$H" PATH="/usr/bin:/bin" bash "$T/bin/dot" cli hook check --help 2>&1)" || RC=$?
assert_false "[[ '$OUT' == *permissionDecision* ]]" "--help takes the full path, never the hook"

# ai ARGS...: `dot ai ARGS...` (plugins/ai/libexec/policy.sh); sets RC
# and OUT, stdout and stderr.
ai() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$JQ_DIR:/usr/bin:/bin" NO_COLOR=1 TERM=dumb LC_ALL=C \
    ${E[@]+"${E[@]}"} bash "$REPO_ROOT/bin/dot" ai "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "dot_ai_policy_runs_dot_policy"
E=(DOT_POLICY_BIN="$H/bin/fake")
ai policy check --policy /p.toml
assert_equals "0|VERDICT" "$RC|$OUT" "its output and status"
assert_equals "validate --policy /p.toml" "$(cat "$H/args")" "validate, with the flags given"
ai policy show --agent codex
assert_equals "0|VERDICT" "$RC|$OUT" "show: its output and status"
assert_equals "show --agent codex" "$(cat "$H/args")" "show, with the flags given"
ai policy
assert_equals "show" "$(cat "$H/args")" "show is the default"
E=(DOT_POLICY_BIN="$H/bin/none")
ai policy check
assert_equals "1" "$RC" "no dot-policy: exit 1"
assert_contains "dot-policy" "$OUT" "named"
assert_contains "not built: install Go with mise, then chezmoi apply" "$OUT" "with the way to build it"

test_start "policy_sh_rejects_another_word"
RC=0
OUT="$(bash "$REPO_ROOT/plugins/ai/libexec/policy.sh" frob 2>&1)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "Usage: dot ai policy show|check [--policy FILE]" "$OUT" "usage"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
