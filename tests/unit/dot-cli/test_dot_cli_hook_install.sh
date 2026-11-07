#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot cli hook install / remove (plugins/cli/libexec/hook-install.sh): the
# receiver wired into Claude Code's and Gemini CLI's settings.json and
# Codex's config.toml, in a sandboxed home, through bin/dot. What else is in
# those files stays as it was; a file it cannot read, or a Codex notify of
# someone else's, is left and reported.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hook-install.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# The coverage runner's tracing, when it is on: env -i would drop it.
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
N=0
JQ_DIR="$(dirname "$(command -v jq)")"

# fresh [AGENT...]: a new home with those agents' config directories and a
# dot on PATH at $B/dot; H is the home.
fresh() {
  local a
  N=$((N + 1))
  H="$WORK/h$N" B="$WORK/b$N"
  mkdir -p "$H" "$B"
  printf '#!/bin/sh\n' >"$B/dot"
  chmod +x "$B/dot"
  for a in "$@"; do mkdir -p "$H/.$a"; done
}

# run ARGS...: `dot cli hook ARGS...` in the home; sets RC and OUT.
run() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$B:$JQ_DIR:/usr/bin:/bin" \
    XDG_STATE_HOME="$H/.state" XDG_CACHE_HOME="$H/.cache" NO_COLOR=1 TERM=dumb \
    bash "$REPO_ROOT/bin/dot" cli hook "$@" 2>&1)" || RC=$?
}

# cmds FILE EVENT: the hook commands for EVENT in a settings.json, one a line.
cmds() { jq -r --arg e "$2" '.hooks[$e][]?.hooks[]?.command' "$1"; }

CLAUDE="'%s/dot' cli hook run --agent claude"

test_start "claude_gets_every_event_and_keeps_the_rest"
fresh claude
S="$H/.claude/settings.json"
printf '{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}\n' >"$S"
chmod 0640 "$S"
run install --agent claude
assert_equals "0" "$RC" "installs"
assert_contains "claude: hook installed in $S" "$OUT" "and says where"
want="$(printf "$CLAUDE" "$B")"
for e in SessionStart UserPromptSubmit PreToolUse PostToolUse PermissionRequest Notification Elicitation Stop StopFailure SessionEnd; do
  assert_contains "$want" "$(cmds "$S" "$e")" "$e runs the receiver"
done
assert_equals "opus" "$(jq -r .model "$S")" "other settings stay"
assert_contains "say done" "$(cmds "$S" Stop)" "and so do other hooks"
assert_equals "-rw-r-----" "$(ls -l "$S" | cut -c1-10)" "the file keeps its mode"

test_start "installing_twice_changes_nothing"
before="$(cat "$S")"
run install --agent claude
assert_equals "0|$before" "$RC|$(cat "$S")" "the file is the same"
assert_contains "claude: already installed in $S" "$OUT" "and says so"

test_start "a_moved_dot_replaces_the_old_entry"
mv "$B" "$B.new" && B="$B.new"
run install --agent claude
assert_equals "1" "$(cmds "$S" Stop | grep -c 'cli hook run --agent claude')" "one entry of ours"
assert_contains "$(printf "$CLAUDE" "$B")" "$(cmds "$S" Stop)" "at the new path"

test_start "remove_takes_out_only_ours"
run remove --agent claude
assert_equals "0" "$RC" "removes"
assert_equals "say done" "$(cmds "$S" Stop)" "the other hook stays"
assert_equals '["Stop"]' "$(jq -c '.hooks | keys' "$S")" "and events left empty are gone"
run remove --agent claude
assert_equals "0" "$RC" "a second remove exits 0"
assert_contains "claude: not installed" "$OUT" "having nothing to do"

test_start "remove_drops_an_emptied_hooks_object"
fresh claude
S="$H/.claude/settings.json"
run install --agent claude
run remove --agent claude
assert_equals "null" "$(jq -c .hooks "$S")" "no empty hooks object is left behind"

test_start "a_linked_settings_file_stays_a_link"
fresh claude
mkdir -p "$H/src"
printf '{"model":"opus"}\n' >"$H/src/claude-settings.json"
ln -s ../src/claude-settings.json "$H/.claude/settings.json"
run install --agent claude
assert_true "[[ -L '$H/.claude/settings.json' ]]" "the link is kept"
assert_contains "cli hook run --agent claude" "$(cmds "$H/src/claude-settings.json" Stop)" "and its target gets the hook"

test_start "every_installed_event_is_one_the_receiver_maps"
for a in claude gemini; do
  fresh "$a"
  run install --agent "$a"
  for e in $(jq -r '.hooks | keys[]' "$H/.$a/settings.json"); do
    printf '{"session_id":"s-%s","hook_event_name":"%s"}' "$e" "$e" |
      env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$H/.state" \
        bash "$REPO_ROOT/bin/dot" cli hook run --agent "$a" >/dev/null 2>&1
    assert_true "[[ -f '$H/.state/dot/cli/agents/$a/s-$e.json' ]]" "$a $e gives a state"
  done
done

test_start "a_file_that_is_not_json_is_left"
fresh claude
S="$H/.claude/settings.json"
printf '{ not json\n' >"$S"
run install --agent claude
assert_equals "3|{ not json" "$RC|$(cat "$S")" "exit 3, file untouched"
assert_contains "is not valid JSON; left as it was" "$OUT" "and says why"

test_start "a_file_it_cannot_write_is_left"
fresh claude
S="$H/.claude/settings.json"
printf '{}\n' >"$S"
chmod 0500 "$H/.claude"
run install --agent claude
chmod 0700 "$H/.claude"
if [[ "$(id -u)" == 0 ]]; then
  echo "  (skipped: root can write a read-only directory)"
else
  assert_equals "3|{}" "$RC|$(cat "$S")" "exit 3, file untouched"
  assert_contains "could not write $S; left as it was" "$OUT" "and says why"
fi

test_start "dry_run_writes_nothing"
fresh claude
run install --agent claude --dry-run
assert_equals "0" "$RC" "a dry run exits 0"
assert_contains "claude: would install the hook in $H/.claude/settings.json" "$OUT" "and says what it would do"
assert_false "[[ -e '$H/.claude/settings.json' ]]" "without writing"

test_start "gemini_gets_its_events_and_a_name"
fresh gemini
S="$H/.gemini/settings.json"
run install --agent gemini
for e in SessionStart BeforeAgent AfterAgent Notification SessionEnd; do
  assert_contains "'$B/dot' cli hook run --agent gemini" "$(cmds "$S" "$e")" "$e runs the receiver"
done
assert_equals "dot-cli-hook" "$(jq -r '.hooks.BeforeAgent[0].hooks[0].name' "$S")" "named, so /hooks can toggle it"
assert_equals "-rw-------" "$(ls -l "$S" | cut -c1-10)" "a new file is private"

test_start "the_receiver_answers_gemini_with_json"
out="$(printf '{"session_id":"g1","hook_event_name":"BeforeAgent"}' |
  env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$H/.state" \
    bash "$REPO_ROOT/bin/dot" cli hook run --agent gemini 2>&1)"
assert_equals "{}" "$out" "Gemini reads stdout as JSON: {} changes nothing"
assert_true "[[ -f '$H/.state/dot/cli/agents/gemini/g1.json' ]]" "and the event is recorded"

test_start "codex_gets_a_top_level_notify"
fresh codex
T="$H/.codex/config.toml"
printf 'model = "o4"\n\n[profiles.fast]\nmodel = "o4-mini"\n' >"$T"
run install --agent codex
assert_equals "0" "$RC" "installs"
assert_equals "notify = [\"$B/dot\", \"cli\", \"hook\", \"run\", \"--agent\", \"codex\"]" "$(head -n 1 "$T")" \
  "notify comes before any table"
assert_contains '[profiles.fast]' "$(cat "$T")" "and the rest stays"
run install --agent codex
assert_equals "1" "$(grep -c '^notify' "$T")" "installing twice keeps one line"
run remove --agent codex
assert_equals "$(printf 'model = "o4"\n\n[profiles.fast]\nmodel = "o4-mini"')" "$(cat "$T")" "remove puts the file back"

test_start "a_notify_of_someone_elses_is_left"
fresh codex
T="$H/.codex/config.toml"
printf 'notify = ["say", "done"]\n' >"$T"
run install --agent codex
assert_equals "3" "$RC" "exit 3"
assert_contains "already has a notify of its own" "$OUT" "and says why"
assert_equals 'notify = ["say", "done"]' "$(cat "$T")" "untouched"
run remove --agent codex
assert_equals "0" "$RC" "remove exits 0"
assert_equals 'notify = ["say", "done"]' "$(cat "$T")" "and leaves it too"

test_start "with_no_agent_it_does_the_ones_present"
fresh claude codex
run install
assert_contains "claude: hook installed" "$OUT" "claude, whose directory exists"
assert_contains "codex: hook installed" "$OUT" "codex too"
assert_false "[[ -e '$H/.gemini' ]]" "gemini, absent, is not created"
fresh
run install
assert_contains "No agent configuration found" "$OUT" "nothing present: says so"
assert_equals "0" "$RC" "and that is not an error"

# unwired: what dot doctor and dot system update read; sets RC and OUT
# (stdout only).
unwired() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$B:$JQ_DIR:/usr/bin:/bin" \
    bash "$REPO_ROOT/plugins/cli/libexec/hook-install.sh" unwired "$@" 2>/dev/null)" || RC=$?
}

test_start "unwired_lists_the_agents_an_install_would_change"
fresh claude codex gemini
unwired
assert_equals "0|claude gemini codex" "$RC|$(tr '\n' ' ' <<<"$OUT" | sed 's/ $//')" "all three, before any install"
run install --agent claude
unwired
assert_equals "gemini codex" "$(tr '\n' ' ' <<<"$OUT" | sed 's/ $//')" "claude drops out once wired"
assert_false "[[ -e '$H/.gemini/settings.json' || -e '$H/.codex/config.toml' ]]" "and nothing is written"
fresh
unwired
assert_equals "0|" "$RC|$OUT" "no agent configured: an empty list, not a sentence"

test_start "bad_usage_exits_1"
fresh claude
run install --agent vim
assert_equals "1" "$RC" "an unknown agent"
assert_contains "--agent takes claude, gemini or codex" "$OUT" "is named"
run install --bogus
assert_equals "1" "$RC" "an unknown option too"
run install --agent xclaude
assert_equals "1" "$RC" "an agent that only ends like one"

test_start "a_link_loop_ends"
fresh claude
ln -s settings.json "$H/.claude/settings.json"
RC=0
timeout 20 env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$B:$JQ_DIR:/usr/bin:/bin" \
  XDG_STATE_HOME="$H/.state" bash "$REPO_ROOT/bin/dot" cli hook install --agent claude >/dev/null 2>&1 || RC=$?
assert_not_equals "124" "$RC" "following links stops instead of hanging"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
