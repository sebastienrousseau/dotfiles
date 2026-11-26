#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# vibe-delegate end to end, with a stub vibe: what it hands vibe (agent,
# model, prompt), what it reports (tool lines, tokens, syntax errors,
# commits or uncommitted changes) and the run-log row it writes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DELEGATE="$REPO_ROOT/defaults/dot_claude/skills/vibe/tools/executable_vibe-delegate"

if ! command -v python3 >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
  echo "SKIP: python3 and git are required"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d -t vibe-run.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/tmp"

# The stub vibe records its arguments and VIBE_ACTIVE_MODEL, streams one
# assistant and two tool messages, then does what $WORK/mode says.
cat >"$WORK/stubs/vibe" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$WORK/args"
printf '%s\n' "\${VIBE_ACTIVE_MODEL:-}" >"$WORK/model"
echo '{"role":"assistant","content":"working on it"}'
echo '{"role":"tool","name":"write_file","path":"app.py","content":"ok"}'
echo '{"role":"tool","name":"bash","content":"Error: no such file"}'
case "\$(cat "$WORK/mode" 2>/dev/null)" in
  commit) echo hi >note.txt && git add note.txt && git commit -qm 'feat: note' ;;
  broken) printf 'def broken(:\n' >broken.py ;;
esac
exit 0
STUB
chmod +x "$WORK/stubs/vibe"

# new_project NAME: a git repository with one commit; prints its path.
new_project() {
  local p="$WORK/$1"
  mkdir -p "$p"
  git -C "$p" init -q
  git -C "$p" -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m init
  printf '%s\n' "$p"
}

# delegate HOME PROJECT [MAX_TURNS AGENT]: one run; sets RC and OUT.
delegate() {
  RC=0
  OUT="$(HOME="$1" TMPDIR="$WORK/tmp" PATH="$WORK/stubs:$PATH" \
    GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.com \
    GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.com \
    bash "$DELEGATE" "$2" "fix the bug: it's \"quoted\"" "${3:-4}" "${4:-}" 30 2>&1)" || RC=$?
}

# db_row HOME: the newest run-log row as "exit|timed_out|files|syntax|agent|tokens|tools".
db_row() {
  python3 - "$1/.local/share/dotfiles-ai.db" <<'PY'
import sqlite3, sys
r = sqlite3.connect(sys.argv[1]).execute(
    "SELECT exit_code, timed_out, files_changed, syntax_errors, agent, tokens_total,"
    " tool_calls FROM runs ORDER BY id DESC LIMIT 1").fetchone()
print("|".join(str(v) for v in r))
PY
}

test_start "missing_workdir_exits_1"
delegate "$WORK/h0" "$WORK/no-such-dir"
assert_equals "1" "$RC" "exit 1"
assert_contains "ERROR: workdir '$WORK/no-such-dir' does not exist" "$OUT" "and says why"

test_start "a_plain_run_reports_and_logs"
mkdir -p "$WORK/h1"
proj="$(new_project plain)"
delegate "$WORK/h1" "$proj"
assert_equals "0" "$RC" "exit 0"
assert_contains "  [vibe] working on it" "$OUT" "the assistant's reply is shown"
assert_contains "  [tool]  file: app.py" "$OUT" "a write names its file"
assert_contains "  [WARN]  Error: no such file" "$OUT" "a tool error is a warning"
assert_contains "Tool calls: 2  |  warns: 1  |  sr_fails: 0" "$OUT" "with the counts"
assert_contains "=== VIBE DONE (exit: 0) ===" "$OUT" "the run is done"
assert_contains "=== UNCOMMITTED CHANGES ===" "$OUT" "no commit: the working tree is summarised"
assert_equals "" "$(grep -F "COMMITS CREATED" <<<"$OUT")" "no COMMITS CREATED line"
assert_equals "" "$(grep -F "(no git)" <<<"$OUT")" "no (no git) line"
assert_equals "0|0|0|0|default|0|2" "$(db_row "$WORK/h1")" "the run-log row"

test_start "the_prompt_and_settings_reach_vibe"
assert_equals "-p|fix the bug: it's \"quoted\"|--trust|--max-turns|4|--output|streaming|--workdir|$proj" \
  "$(paste -sd '|' "$WORK/args")" "the prompt arrives intact, with no --agent"
assert_equals "" "$(cat "$WORK/model")" "and no model override"

test_start "agent_and_model_override_reach_vibe"
mkdir -p "$WORK/h2/.local/share"
printf ' mistral-small \n' >"$WORK/h2/.local/share/vibe-model.flag"
delegate "$WORK/h2" "$proj" 6 reviewer
assert_equals "--agent|reviewer|-p" "$(head -3 "$WORK/args" | paste -sd '|' -)" "--agent comes first"
assert_equals "mistral-small" "$(cat "$WORK/model")" "VIBE_ACTIVE_MODEL is the picked model"
assert_contains "Model   : mistral-small" "$OUT" "and the banner shows it"
assert_contains "Agent   : reviewer" "$OUT" "and the agent"
assert_equals "reviewer" "$(db_row "$WORK/h2" | cut -d'|' -f5)" "the run log records the agent"

test_start "a_commit_is_reported"
mkdir -p "$WORK/h3"
echo commit >"$WORK/mode"
delegate "$WORK/h3" "$(new_project committing)"
assert_contains "=== COMMITS CREATED ===" "$OUT" "the new commit is reported"
assert_contains "feat: note" "$OUT" "by its subject"
assert_equals "" "$(grep -F "UNCOMMITTED CHANGES" <<<"$OUT")" "no UNCOMMITTED CHANGES line"

test_start "a_syntax_error_is_reported_and_logged"
mkdir -p "$WORK/h4"
echo broken >"$WORK/mode"
delegate "$WORK/h4" "$(new_project broken)"
assert_contains "  [SYNTAX ERROR] broken.py" "$OUT" "the broken file is named"
assert_contains "=== SYNTAX ERRORS: 1 in 1 check(s)" "$OUT" "and counted"
assert_equals "0|0|1|1" "$(db_row "$WORK/h4" | cut -d'|' -f1-4)" "the run log has one changed file and one error"
rm -f "$WORK/mode"

test_start "session_tokens_are_reported_and_logged"
mkdir -p "$WORK/h5/.vibe/logs/session/s1"
cat >"$WORK/h5/.vibe/logs/session/s1/meta.json" <<'JSON'
{"config": {"active_model": "devstral"},
 "stats": {"last_turn_prompt_tokens": 300, "last_turn_completion_tokens": 100,
           "session_total_llm_tokens": 4000}}
JSON
delegate "$WORK/h5" "$proj"
assert_contains "Model               : devstral" "$OUT" "the session's model"
assert_contains "Delegate tokens (run): 4,000  (last turn: 300+100)" "$OUT" "the run total, not the last turn"
assert_equals "4000" "$(db_row "$WORK/h5" | cut -d'|' -f6)" "the run log has the run total"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
