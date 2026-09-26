#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2016,SC2034
# Unit tests for dot CLI agent commands (scripts/dot/commands/agent.sh).
#
# Every case runs the module: `dot mode|agent <sub>` through meta.sh (which
# sources agent.sh for cmd_mode), against fixture profile and card JSON
# passed via AGENT_PROFILE_CONFIG / AGENT_CARD_CONFIG. State, session log
# and checkpoints live in a mktemp HOME/XDG tree; nothing outside it is
# written, and the only repo files read are the module, its libs and the
# read-only A2A conformance check.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

AGENT_FILE="$REPO_ROOT/scripts/dot/commands/agent.sh"
META_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/agent-cmd.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state" XDG_DATA_HOME="$HOME/.local/share"
export NO_COLOR=1 DOTFILES_SHOW_LOGO=0 DOTFILES_ACCESSIBILITY=1
unset AGENT_STATE_FILE DOT_AGENT_PROFILE DOT_AGENT_CHECKPOINT_ID
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
STATE_FILE="$XDG_CONFIG_HOME/dotfiles/agent-mode.env"
CHECKPOINTS="$XDG_STATE_HOME/dotfiles/checkpoints"
SESSIONS="$XDG_STATE_HOME/dotfiles/agent-sessions.jsonl"

export AGENT_PROFILE_CONFIG="$WORK/agent-profiles.json"
cat >"$AGENT_PROFILE_CONFIG" <<'JSON'
{
  "defaultProfile": "ask",
  "rbac": {
    "defaultRole": "developer",
    "enforcement": "advisory",
    "roles": { "developer": { "allowedProfiles": ["ask", "sandbox"] } }
  },
  "profiles": {
    "ask": {
      "description": "Fixture read-only profile.",
      "approval": "manual", "filesystem": "read-only", "network": "off",
      "mcpProfile": "strict-local", "maxSteps": 1
    },
    "sandbox": {
      "description": "Fixture bounded-write profile.",
      "approval": "on-request", "filesystem": "workspace-write", "network": "limited",
      "mcpProfile": "fixture-mcp", "maxSteps": 7
    }
  }
}
JSON
export AGENT_CARD_CONFIG="$WORK/agent-card.json"
cat >"$AGENT_CARD_CONFIG" <<'JSON'
{"name":"fixture-agent","version":"9.8.7","protocols":["mcp","a2a"],
 "defaultProfile":"ask","platforms":["macOS","Linux"]}
JSON

OUT="$WORK/out"
# mode <args…> — run `dot mode <args…>` via meta.sh; prints the exit code.
mode() {
  local rc=0
  "$REAL_BASH" "$META_FILE" mode "$@" >"$OUT" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}
# line <label> — the rendered row for a ui_ok/ui_info label, spaces squeezed.
line() { tr -s " " <"$OUT" | sed "s/^ //" | grep -F "] $1 " | head -1; }

# ===========================================================================
# Sourced alone: lib/dot/utils.sh turns strict mode on itself, so loading it
# first would hide a module that dropped its own `set -euo pipefail`.
test_start "agent_module_sets_strict_mode_when_sourced"
opts="$("$REAL_BASH" -c 'set +euo pipefail
  source "$1"
  printf "%s %s" "$-" "$(set -o | grep -E "^pipefail" | tr -s " \t" " ")"' _ "$AGENT_FILE")"
assert_contains "e" "${opts%% *}" "errexit on"
assert_contains "u" "${opts%% *}" "nounset on"
assert_contains "pipefail on" "$opts" "pipefail on"

test_start "agent_cmd_defines_mode"
rc="$(mode current)"
assert_equals "0" "$rc" "mode current exits 0"
assert_equals "[OK] Profile ask" "$(line Profile)" "no state: default profile from the config"
rc="$("$REAL_BASH" "$META_FILE" agent current >"$OUT" 2>&1 </dev/null && echo 0 || echo $?)"
assert_equals "0" "$rc" "agent is an alias of mode"
assert_equals "[OK] Profile ask" "$(line Profile)" "agent alias reaches cmd_mode"
rc="$(mode --verbose)"
assert_equals "[OK] Profile ask" "$(line Profile)" "no subcommand (or a flag) means current"

test_start "agent_cmd_helpers_profiles_file_override"
rc="$(AGENT_PROFILE_CONFIG="$WORK/missing.json" mode list)"
assert_equals "1" "$rc" "missing profile config is fatal"
assert_file_contains "$OUT" "Agent profile config not found: $WORK/missing.json" "override path honoured"
rc="$(AGENT_PROFILE_CONFIG="" mode show apply)"
assert_equals "0" "$rc" "unset override falls back to the shipped profiles"
assert_file_contains "$OUT" "on-request" "shipped apply profile shown"

test_start "agent_cmd_mode_list"
rc="$(mode list)"
assert_equals "0" "$rc" "list exits 0"
assert_equals "[OK] ask Fixture read-only profile. [current]" "$(line ask)" "current profile marked"
assert_equals "[INFO] sandbox Fixture bounded-write profile." "$(line sandbox)" "other profile listed"

test_start "agent_cmd_mode_show"
rc="$(mode show sandbox)"
assert_equals "0" "$rc" "show exits 0"
assert_equals "[OK] Description Fixture bounded-write profile." "$(line Description)" "description"
assert_equals "[OK] Max steps 7" "$(line 'Max steps')" "max steps"
assert_equals "[OK] MCP fixture-mcp" "$(line MCP)" "mcp profile"
rc="$(mode show nope)"
assert_equals "1" "$rc" "unknown profile exits 1"
assert_file_contains "$OUT" "Unknown agent profile: nope" "unknown profile named"
rc="$(mode show)"
assert_equals "1" "$rc" "show without a name exits 1"

test_start "agent_cmd_mode_set_and_current_profile"
rc="$(mode set sandbox)"
assert_equals "0" "$rc" "set exits 0"
assert_file_exists "$STATE_FILE" "state file written under XDG_CONFIG_HOME"
assert_equals "DOT_AGENT_PROFILE=sandbox
DOT_AGENT_APPROVAL=on-request
DOT_AGENT_FILESYSTEM=workspace-write
DOT_AGENT_NETWORK=limited
DOT_AGENT_MCP_PROFILE=fixture-mcp
DOT_AGENT_MAX_STEPS=7" "$(<"$STATE_FILE")" "state file carries the profile policy"
rc="$(mode current)"
assert_equals "[OK] Profile sandbox" "$(line Profile)" "current reads the state file"
assert_equals "[OK] Network limited" "$(line Network)" "current shows the profile policy"
printf 'DOT_AGENT_PROFILE=\n' >"$STATE_FILE"
rc="$(mode current)"
assert_equals "[OK] Profile ask" "$(line Profile)" "empty state entry falls back to the default"
rc="$(mode set nope)"
assert_equals "1" "$rc" "set of an unknown profile exits 1"
rc="$(mode set sandbox)"

test_start "agent_cmd_mode_run_applies_profile_env"
rc="$(mode run ask "$REAL_BASH" -c 'env | grep ^DOT_AGENT_ | sort')"
assert_equals "0" "$rc" "run exits 0"
env_out="$(grep '^DOT_AGENT_' "$OUT")"
assert_equals "DOT_AGENT_APPROVAL=manual
DOT_AGENT_FILESYSTEM=read-only
DOT_AGENT_MAX_STEPS=1
DOT_AGENT_MCP_PROFILE=strict-local
DOT_AGENT_NETWORK=off
DOT_AGENT_PROFILE=ask" "$env_out" "named profile's policy exported to the command"
rc="$(mode run "$REAL_BASH" -c 'echo "p=$DOT_AGENT_PROFILE"; exit 7')"
assert_equals "7" "$rc" "command exit code propagated"
assert_file_contains "$OUT" "p=sandbox" "no profile named: the current one applies"
assert_file_contains "$SESSIONS" '"event":"run_finish","profile":"sandbox","status":"failed"' "failure logged"
rc="$(mode run)"
assert_equals "1" "$rc" "run without a command exits 1"

test_start "agent_cmd_mode_doctor"
rc="$(mode doctor)"
assert_equals "0" "$rc" "doctor exits 0"
assert_equals "[OK] Default profile ask" "$(line 'Default profile')" "default profile checked"
printf '{"defaultProfile":"gone","profiles":{}}\n' >"$WORK/bad.json"
rc="$(AGENT_PROFILE_CONFIG="$WORK/bad.json" mode doctor)"
assert_equals "1" "$rc" "missing default profile fails"
assert_file_contains "$OUT" "Default profile missing" "reason given"

test_start "agent_cmd_mode_card"
rc="$(mode card)"
assert_equals "0" "$rc" "card exits 0"
assert_equals "[OK] Name fixture-agent" "$(line Name)" "card name"
assert_equals "[OK] Protocols mcp, a2a" "$(line Protocols)" "card protocols"
rc="$(mode card --json)"
assert_equals "9.8.7" "$(sed -n '/^{/,$p' "$OUT" | jq -r .version)" "card --json prints the card"

test_start "agent_cmd_checkpoint_save_and_replay"
rc="$(DOT_AGENT_CHECKPOINT_ID=cp1 mode checkpoint save ask "$REAL_BASH" -c 'echo "$DOT_AGENT_PROFILE" >"$0"' "$WORK/replayed")"
assert_equals "0" "$rc" "save exits 0"
assert_file_exists "$CHECKPOINTS/cp1.json" "checkpoint file written"
assert_equals "ask saved" "$(jq -r '"\(.profile) \(.status)"' "$CHECKPOINTS/cp1.json")" "profile and status recorded"
assert_file_not_exists "$WORK/replayed" "save does not run the command"
rc="$(mode checkpoint replay cp1)"
assert_equals "0" "$rc" "replay exits 0"
assert_equals "ask" "$(cat "$WORK/replayed" 2>/dev/null)" "replay runs the argv under the saved profile"
rc="$(mode checkpoint replay nope)"
assert_equals "1" "$rc" "unknown checkpoint exits 1"
assert_file_contains "$OUT" "Checkpoint not found: nope" "unknown checkpoint named"
rc="$(mode checkpoint frob)"
assert_equals "1" "$rc" "unknown checkpoint action exits 1"
assert_file_contains "$OUT" "Usage: dot agent checkpoint [save|list|show|replay]" "checkpoint usage"

test_start "agent_cmd_mode_conformance"
rc="$(mode conformance --json --strict)"
assert_equals "0" "$rc" "conformance passes on the shipped cards"
report="$(sed -n '/^{/,$p' "$OUT" | jq -r '"\(.specVersion) strict=\(.strict) \(.status)"' 2>/dev/null)"
assert_equals "0.3 strict=true healthy" "$report" "flags reach the A2A conformance check"

test_start "agent_cmd_unknown_subcommand"
rc="$(mode frob)"
assert_equals "1" "$rc" "unknown subcommand exits 1"
assert_file_contains "$OUT" "Usage: dot mode [list|current|show|set|run|doctor|card|log|checkpoint|conformance|a2a-card]" "usage printed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
