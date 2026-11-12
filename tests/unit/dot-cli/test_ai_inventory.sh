#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot ai inventory show [--json] (plan P1.5): each installed agent's
# version, pin, sign-in and hooks, the policy's digest, and the drift
# between them, through bin/dot in a sandboxed home whose agents are stubs.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-inventory.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
H="$WORK/home"
mkdir -p "$H/.claude" "$H/.config/dotfiles" "$WORK/bin" "$WORK/jq"
# jq alone: its directory may hold real agents, which would join the stubs.
ln -s "$(command -v jq)" "$WORK/jq/jq"
JQ_DIR="$WORK/jq"
pin_of() { awk -v k="\"$1\"" '/^\[/ { t = ($0 == "[ai_tools]"); next } t && $1 == k { gsub(/"/, "", $3); print $3; exit }' "$REPO_ROOT/defaults/.chezmoidata.toml"; }
CODEX_PIN="$(pin_of npm:@openai/codex)"
CRUSH_PIN="$(pin_of aqua:charmbracelet/crush)"

# stub NAME OUTPUT: an agent binary that prints OUTPUT for --version.
stub() {
  printf '#!/bin/sh\n[ "$1" = --version ] && printf "%%s\\n" "%s"\n' "$2" >"$WORK/bin/$1"
  chmod +x "$WORK/bin/$1"
}
stub claude "2.1.0 (Claude Code)"
stub codex "codex-cli 0.0.1"
stub crush "Downloading crush 9.9.9/linux_amd64...
crush version $CRUSH_PIN"
# security: the macOS keychain; its exit status is in $WORK/keychain-rc.
printf '#!/bin/sh\nexit "$(cat %s/keychain-rc)"\n' "$WORK" >"$WORK/bin/security"
chmod +x "$WORK/bin/security"
printf '0\n' >"$WORK/keychain-rc"
printf '{}\n' >"$H/.claude/settings.json"
printf 'schema = "ai-policy.v1"\ndefault_mode = "ask"\n' >"$H/.config/dotfiles/ai-policy.toml"
POLICY_SHA="$( (shasum -a 256 "$H/.config/dotfiles/ai-policy.toml" 2>/dev/null || sha256sum "$H/.config/dotfiles/ai-policy.toml") | awk '{print $1}')"

# inv ARGS...: dot ai inventory ARGS... in the sandboxed home; RC, OUT.
# Extra NAME=value pairs go in E.
E=()
inv() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/bin:$JQ_DIR:/usr/bin:/bin" NO_COLOR=1 TERM=dumb LC_ALL=C \
    OPENAI_API_KEY=sk-test ${E[@]+"${E[@]}"} bash "$REPO_ROOT/bin/dot" ai inventory "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "show_lists_each_installed_agent"
inv show
assert_equals "0" "$RC" "exit 0"
assert_contains "AGENT" "$OUT" "a header"
assert_contains "claude         2.1.0        -            login    missing" "$OUT" "claude: native, so no pin; signed in; hooks missing"
assert_contains "codex          0.0.1        $(printf '%-12s' "$CODEX_PIN") key      n/a" "$OUT" "codex: off its pin, an API key, no ~/.codex"
assert_contains "crush          $(printf '%-12s' "$CRUSH_PIN") $(printf '%-12s' "$CRUSH_PIN") unknown  n/a" "$OUT" "crush: the version line, not the download noise"
assert_equals "no" "$([[ "$OUT" == *aider* ]] && echo yes || echo no)" "an agent that is not installed is not listed"

test_start "show_names_the_policy_and_the_drift"
assert_contains "policy         sha256:${POLICY_SHA:0:12} $H/.config/dotfiles/ai-policy.toml" "$OUT" "the policy's digest and path"
assert_contains "drift          codex: 0.0.1 is off its pin $CODEX_PIN" "$OUT" "a version off its pin"
assert_contains "drift          claude: hooks missing (dot cli hook install)" "$OUT" "hooks missing"
assert_equals "no" "$([[ "$OUT" == *"crush:"* ]] && echo yes || echo no)" "an agent at its pin is no drift"

test_start "json_is_inventory_v1"
inv show --json
assert_equals "0" "$RC" "exit 0"
assert_equals "ai/inventory.v1|$POLICY_SHA|2" "$(jq -r '[.schema, .policy.sha256, (.drift | length)] | join("|")' <<<"$OUT")" "schema, digest, drift count"
assert_equals "0.0.1|$CODEX_PIN|key|n/a" "$(jq -r '.agents[] | select(.name == "codex") | [.version, .pin, .auth, .hooks] | join("|")' <<<"$OUT")" "codex's row"
assert_equals "null" "$(jq -c '.agents[] | select(.name == "claude") | .pin' <<<"$OUT")" "no pin: null"
assert_equals "claude:hooks codex:version" "$(jq -r '[.drift[] | "\(.agent):\(.kind)"] | sort | join(" ")' <<<"$OUT")" "each finding: its agent and kind"
if python3 -c 'import jsonschema' 2>/dev/null; then
  RC=0
  python3 -c 'import json, sys
from jsonschema import Draft202012Validator
Draft202012Validator(json.load(open(sys.argv[1]))).validate(json.loads(sys.argv[2]))' \
    "$REPO_ROOT/schemas/cli/ai-inventory.v1.schema.json" "$OUT" || RC=$?
  assert_equals "0" "$RC" "it validates"
else
  echo "  jsonschema not installed: schema check skipped"
fi

test_start "sign_in_is_where_each_agent_keeps_it"
printf '44\n' >"$WORK/keychain-rc"
E=(OPENAI_API_KEY=)
mkdir -p "$H/.codex"
: >"$H/.codex/auth.json"
inv show --json
assert_equals "none|none" "$(jq -r '[.agents[] | select(.name == "claude" or .name == "codex") | .auth] | join("|")' <<<"$OUT")" "no item in the keychain, an empty auth.json: none"
printf '{"tokens":{}}\n' >"$H/.codex/auth.json"
printf '{"claudeAiOauth":{}}\n' >"$H/.claude/.credentials.json"
inv show --json
assert_equals "login|login" "$(jq -r '[.agents[] | select(.name == "claude" or .name == "codex") | .auth] | join("|")' <<<"$OUT")" "a credentials file: login"
rm -f "$H/.claude/.credentials.json"
printf '51\n' >"$WORK/keychain-rc"
inv show --json
assert_equals "unknown" "$(jq -r '.agents[] | select(.name == "claude") | .auth' <<<"$OUT")" "a keychain that will not say: unknown"
E=(ANTHROPIC_API_KEY=sk-ant-test)
inv show --json
assert_equals "key" "$(jq -r '.agents[] | select(.name == "claude") | .auth' <<<"$OUT")" "an API key wins"
E=()

test_start "hooks_wired_and_no_policy"
printf '0\n' >"$WORK/keychain-rc"
rm -f "$H/.config/dotfiles/ai-policy.toml"
env -i HOME="$H" PATH="$WORK/bin:$JQ_DIR:/usr/bin:/bin" bash "$REPO_ROOT/plugins/cli/libexec/hook-install.sh" install --agent claude --agent codex >/dev/null 2>&1
inv show --json
assert_equals "wired|wired" "$(jq -r '[.agents[] | select(.name == "claude" or .name == "codex") | .hooks] | join("|")' <<<"$OUT")" "wired once installed"
assert_equals "null|1" "$(jq -c '.policy.sha256' <<<"$OUT")|$(jq '.drift | length' <<<"$OUT")" "no policy: null; only codex's version drifts"
inv show
assert_contains "policy         none" "$OUT" "no policy, said so"

test_start "hooks_in_a_settings_file_that_is_not_json_are_unknown"
cp "$H/.claude/settings.json" "$WORK/settings.json.good"
printf 'not json\n' >"$H/.claude/settings.json"
inv show --json
assert_equals "unknown" "$(jq -r '.agents[] | select(.name == "claude") | .hooks' <<<"$OUT")" "not wired, not missing: unknown"
assert_equals "wired" "$(jq -r '.agents[] | select(.name == "codex") | .hooks' <<<"$OUT")" "the other agent is still read"
cp "$WORK/settings.json.good" "$H/.claude/settings.json"

test_start "a_version_that_does_not_parse_is_no_drift"
stub codex "unknown build"
inv show --json
assert_equals "null|0" "$(jq -c '(.agents[] | select(.name == "codex") | .version)' <<<"$OUT")|$(jq '.drift | length' <<<"$OUT")" "no version, no drift"

test_start "no_jq"
mkdir -p "$WORK/nojq"
for t in bash dirname basename cat awk sed tr mktemp rm uname date hostname head tail grep env ls mkdir; do
  ln -sf "$(command -v "$t")" "$WORK/nojq/$t"
done
RC=0
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/nojq" NO_COLOR=1 TERM=dumb \
  bash "$REPO_ROOT/plugins/ai/libexec/inventory.sh" show 2>&1)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "needs jq" "$OUT" "says so"

test_start "bad_usage"
RC=0
OUT="$(bash "$REPO_ROOT/plugins/ai/libexec/inventory.sh" frob 2>&1)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "Usage: dot ai inventory show [--json]" "$OUT" "usage"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
