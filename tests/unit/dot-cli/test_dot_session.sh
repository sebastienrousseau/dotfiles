#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016 # the fakes are written with literal $
# dot session (plugins/session/dot-session) on the agent runtime
# (lib/dot/agent-runtime.sh): on
# herdr-core a fake records the calls; on tmux a real server on a private
# socket starts, lists and stops sessions. HOME is a temp dir.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d /tmp/dot-ses.XXXXXX)"
SOCK="dot-ses-$$"
trap 'tmux -L "$SOCK" kill-server 2>/dev/null; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
cat >"$WORK/bin/herdr-core" <<'EOF2'
#!/bin/sh
echo "hc $*" >>"$WORK/calls"
[ "$1" != ls ] || cat "$WORK/hc-ls" 2>/dev/null || echo '{"terminals":[]}'
EOF2
# The picker: dot-ui pick chooses the second line it is offered.
cat >"$WORK/bin/dot-ui" <<'EOF2'
#!/bin/sh
sed -n 2p
EOF2
printf '#!/bin/sh\nexec tmux -L "%s" "$@"\n' "$SOCK" >"$WORK/tmux"
chmod +x "$WORK/bin/herdr-core" "$WORK/bin/dot-ui" "$WORK/tmux"

# session RUNTIME ARGS...: the real `dot session` route; sets RC and OUT.
session() {
  local runtime="$1"
  shift
  RC=0
  OUT="$(env -u TMUX -u NO_COLOR HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" PATH="$WORK/bin:$PATH" \
    WORK="$WORK" DOT_RUNTIME="$runtime" DOT_TMUX="$WORK/tmux" bash "$REPO_ROOT/bin/dot" session "$@" 2>&1 </dev/null)" || RC=$?
}
calls() { paste -sd '|' "$WORK/calls" 2>/dev/null; }

test_start "hc_new_list_open_stop"
: >"$WORK/calls"
session hc new web --cwd /srv -- bun dev
assert_equals "0|hc run --bg --name web --cwd /srv --label dot=session -- bun dev" "$RC|$(calls)" \
  "new starts it detached, labelled a session, with its command"
assert_contains "dot session open web" "$OUT" "and says how to open it"
: >"$WORK/calls"
session hc new shell --cwd /srv
assert_equals "0|hc run --bg --name shell --cwd /srv --label dot=session --" "$RC|$(calls)" \
  "--cwd with no command after it"
: >"$WORK/calls"
session hc list
assert_equals "hc ls" "$(calls)" "list is hc ls"
: >"$WORK/calls"
session hc open web
assert_equals "hc attach web" "$(calls)" "open attaches"
: >"$WORK/calls"
session hc stop web
assert_equals "hc kill web" "$(calls)" "stop kills its program"

test_start "select_picks_and_opens"
echo '{"terminals":[{"name":"api"},{"name":"web"}]}' >"$WORK/hc-ls"
: >"$WORK/calls"
session hc
assert_equals "hc ls --json|hc attach web" "$(calls)" "no verb: pick one (here the second) and open it"
echo '{"terminals":[]}' >"$WORK/hc-ls"
session hc select
assert_equals "0" "$RC" "none is not an error"
assert_contains "No sessions" "$OUT" "none: says how to make one"

test_start "refusals"
session hc open
assert_equals "1" "$RC" "open needs a name"
session hc new 'Not Valid'
assert_contains "1-32 of a-z 0-9 - _" "$OUT" "a name hc would refuse"
session hc frob
assert_equals "127" "$RC" "an unknown verb (N10)"
OUT="$(env HOME="$WORK/home" PATH="$WORK/bin:$PATH" DOT_RUNTIME=hc bash "$REPO_ROOT/plugins/session/dot-session" frob 2>&1)" &&
  RC=0 || RC=$?
assert_equals "1" "$RC" "the entry itself refuses an unknown word"
assert_contains "unknown 'dot session' command" "$OUT" "and says so"
OUT="$(env HOME="$WORK/home" PATH="/usr/bin:/bin" DOT_HC=/nonexistent DOT_TMUX=/nonexistent \
  /bin/bash "$REPO_ROOT/bin/dot" session list 2>&1)" && RC=0 || RC=$?
assert_equals "1" "$RC" "neither herdr-core nor tmux"
assert_contains "dot ai install hc" "$OUT" "says how to get one"

if command -v tmux >/dev/null 2>&1; then
  test_start "tmux_new_list_stop"
  session tmux new api -- sleep 60
  assert_equals "0" "$RC" "new starts a detached tmux session"
  session tmux new web
  assert_equals "api web" "$("$WORK/tmux" list-sessions -F '#{session_name}' | paste -sd ' ' -)" "both live"
  assert_equals "" "$("$WORK/tmux" show-options -v -t =api: @dot_agent 2>/dev/null)" "not marked as an agent"
  session tmux list
  assert_contains "api" "$OUT" "list names them"
  assert_contains "detached" "$OUT" "and says whether attached"
  session tmux new api
  assert_equals "1" "$RC" "a taken name fails"
  session tmux stop api
  assert_equals "web" "$("$WORK/tmux" list-sessions -F '#{session_name}')" "stop ends it"
else
  echo "  - tmux not installed: the tmux cases are skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
