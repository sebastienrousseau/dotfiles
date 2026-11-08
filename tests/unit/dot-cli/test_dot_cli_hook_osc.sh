#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot cli hook run, OSC 7501: inside herdr ($HC_TERMINAL_ID set), the hook
# also tells the agent's terminal what the agent is doing, as the Program
# Status Protocol record herdr-core parses
# (ESC ] 7501 ; state=<s>[:kind=<k>]:app=<agent> ESC \). Each case runs the
# hook under a real pseudo-terminal: either as its controlling terminal
# (Codex's notify), or from a session of its own whose parent holds it
# (Claude Code and Gemini CLI start hooks that way), and reads what the
# terminal received.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "  (no python3 for a pseudo-terminal: OSC 7501 cases skipped)"
  print_summary
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hook-osc.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# On a pty, as its controlling terminal ("own") or from a new session under
# a parent that has it ("detached"); prints what the terminal received.
cat >"$WORK/pty.py" <<'EOF'
import os, pty, sys
mode, cmd = sys.argv[1], sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    if mode == "detached":
        child = os.fork()
        if child == 0:
            os.setsid()
            os.execvp(cmd[0], cmd)
        os.waitpid(child, 0)
        os._exit(0)
    os.execvp(cmd[0], cmd)
out = b""
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
os.waitpid(pid, 0)
sys.stdout.write(out.decode("latin-1").replace("\x1b", "<ESC>"))
EOF
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done

# osc MODE AGENT PAYLOAD [VAR=value...]: the hook for AGENT on a pty, the
# payload as its last argument (as Codex's notify passes it); sets OUT.
osc() {
  local mode="$1" agent="$2" payload="$3"
  shift 3
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$WORK/home" PATH="/usr/bin:/bin" \
    XDG_STATE_HOME="$WORK/state" TERM=dumb "$@" \
    python3 -I "$WORK/pty.py" "$mode" bash "$REPO_ROOT/bin/dot" cli hook run --agent "$agent" "$payload" 2>&1)"
}

ev() { printf '{"hook_event_name":"%s","session_id":"s1"%s}' "$1" "${2:+,\"notification_type\":\"$2\"}"; }
rec() { printf '<ESC>]7501;state=%s:app=%s<ESC>\134' "$1" "$2"; }
# no_record MESSAGE: the terminal got no 7501 record.
no_record() { assert_equals "none" "$([[ "$OUT" == *7501* ]] && echo sent || echo none)" "$1"; }

test_start "each_event_reaches_herdr_as_its_7501_state"
while IFS='|' read -r event ntype want; do
  osc own gemini "$(ev "$event" "$ntype")" HC_TERMINAL_ID=t1
  assert_contains "$(rec "$want" gemini)" "$OUT" "$event${ntype:+ ($ntype)} is $want"
done <<'EOF'
SessionStart||idle
BeforeAgent||working
UserPromptSubmit||working
PreToolUse||working
PostToolUse||working
PermissionRequest||blocked:kind=permission
Elicitation||blocked:kind=question
Notification|permission_prompt|blocked:kind=question
Notification|idle_prompt|idle
AfterAgent||done
Stop||done
StopFailure||error
SessionEnd||clear
EOF

test_start "codex_turn_complete_is_done"
osc own codex '{"type":"agent-turn-complete","thread-id":"th1"}' HC_TERMINAL_ID=t1
assert_contains "$(rec "done" codex)" "$OUT" "Codex's notify payload"

test_start "a_hook_in_a_session_of_its_own_finds_the_agent_terminal"
osc detached gemini "$(ev PreToolUse)" HC_TERMINAL_ID=t1
assert_contains "$(rec working gemini)" "$OUT" "through its parent's terminal"

test_start "outside_herdr_the_terminal_gets_nothing"
osc own gemini "$(ev PreToolUse)"
no_record "no HC_TERMINAL_ID: no record"
osc own gemini "$(ev PreToolUse)" HC_TERMINAL_ID=t1 DOT_HOOK_OSC7501=0
no_record "DOT_HOOK_OSC7501=0 turns it off in herdr"
osc own gemini "$(ev PreToolUse)" DOT_HOOK_OSC7501=1
assert_contains "$(rec working gemini)" "$OUT" "DOT_HOOK_OSC7501=1 turns it on for another 7501 terminal"

test_start "claude_code_reports_itself_so_the_hook_does_not"
osc own claude "$(ev PreToolUse)" HC_TERMINAL_ID=t1
no_record "no second record for Claude Code"
assert_contains '"state":"running"' "$(cat "$WORK/state/dot/cli/agents/claude/s1.json" 2>/dev/null)" "its state file is still written"

test_start "an_event_with_no_state_sends_nothing"
osc own gemini "$(ev BeforeModel)" HC_TERMINAL_ID=t1
no_record "an unmapped event"

print_summary
