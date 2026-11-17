#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# defaults/dot_config/ollama/executable_activate.sh runs under `env -i` with
# recording stubs for chezmoi, plutil, launchctl, pgrep, ollama, python3 and
# sysctl. Stray servers are real child processes, so the script's `kill`
# acts on them. Nothing reaches the real launchd or Ollama.
# shellcheck disable=SC1090,SC1091
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ACTIVATE="$REPO_ROOT/defaults/dot_config/ollama/executable_activate.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ollama-activate.XXXXXX")"
CHILDREN=()
cleanup() {
  for p in ${CHILDREN[@]+"${CHILDREN[@]}"}; do kill "$p" 2>/dev/null || true; done
  rm -rf "$WORK"
}
trap cleanup EXIT
HOME_DIR="$WORK/home"
CALLS="$WORK/calls"
STUBS="$WORK/stubs"
TOOLS="$WORK/tools"
mkdir -p "$HOME_DIR" "$CALLS" "$STUBS" "$TOOLS"

mkstub() {
  {
    printf '#!%s\n' "$REAL_BASH"
    cat
  } >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}
mkstub chezmoi <<'EOF'
printf '%s\n' "$*" >>"$CALLS/chezmoi"
[[ "$1" == cat ]] && echo '<plist/>'
exit 0
EOF
mkstub plutil <<'EOF'
cat >/dev/null
exit 0
EOF
# `print` fails until the agent is loaded: FAKE_LOADED=1, or a bootstrap.
mkstub launchctl <<'EOF'
printf '%s\n' "$*" >>"$CALLS/launchctl"
case "$1" in
  print)
    [[ "${FAKE_LOADED:-0}" == 1 || -e "$CALLS/bootstrapped" ]] || exit 113
    printf '\tstate = running\n\tpid = %s\n' "${FAKE_AGENT_PID:-}"
    ;;
  bootstrap) : >"$CALLS/bootstrapped" ;;
esac
exit 0
EOF
mkstub pgrep <<'EOF'
printf '%s\n' ${FAKE_SERVE_PIDS:-}
EOF
# `ollama list` succeeds from call number FAKE_READY_AFTER on.
mkstub ollama <<'EOF'
printf '%s\n' "$*" >>"$CALLS/ollama"
if [[ "$1" == list ]]; then
  n="$(grep -c '^list$' "$CALLS/ollama")"
  ((n >= ${FAKE_READY_AFTER:-1})) || exit 1
fi
exit 0
EOF
mkstub python3 <<'EOF'
printf '%s\n' "$*" >>"$CALLS/python3"
EOF
mkstub sysctl <<'EOF'
echo "vm.swapusage: total = 0M"
EOF
mkstub sleep <<'EOF'
exit 0
EOF
for t in awk grep seq cat id; do ln -s "$(command -v "$t")" "$TOOLS/$t"; done

run_activate() { # [VAR=value...]
  rm -f "$CALLS"/*
  command env -i HOME="$HOME_DIR" PATH="$STUBS:$TOOLS" CALLS="$CALLS" "$@" \
    "$REAL_BASH" "$ACTIVATE" >"$WORK/out" 2>"$WORK/err"
}
spawn() { # a child that stands in for an `ollama serve`; its pid in $last
  "$REAL_BASH" -c 'exec -a ollama-serve-fixture sleep 300' &
  last=$!
  CHILDREN+=("$last")
}
alive() { kill -0 "$1" 2>/dev/null && echo yes || echo no; }

uid="$(id -u)"
label="gui/$uid/com.sebastienrousseau.ollama"

test_start "ollama_activate_stops_only_servers_launchd_does_not_own"
spawn
agent="$last"
spawn
stray="$last"
run_activate FAKE_LOADED=1 FAKE_AGENT_PID="$agent" FAKE_SERVE_PIDS="$agent $stray"
assert_equals 0 $? "activate exits 0: $(cat "$WORK/err")"
assert_equals yes "$(alive "$agent")" "the server launchd runs is left alone"
assert_equals no "$(alive "$stray")" "an ad-hoc ollama serve is stopped"

test_start "ollama_activate_kickstarts_a_loaded_agent"
assert_equals "kickstart -k $label" "$(grep -v '^print' "$CALLS/launchctl")" \
  "a loaded agent is restarted in place, not bootstrapped again"
assert_equals "apply $HOME_DIR/Library/LaunchAgents/com.sebastienrousseau.ollama.plist" \
  "$(grep '^apply' "$CALLS/chezmoi")" "only the plist is applied"
assert_contains "$HOME_DIR/.config/ollama/bench.py" "$(cat "$CALLS/python3")" \
  "the benchmark runs once the server answers"

test_start "ollama_activate_bootstraps_an_unloaded_agent"
run_activate FAKE_LOADED=0
assert_equals 0 $? "activate exits 0: $(cat "$WORK/err")"
assert_equals "bootstrap gui/$uid $HOME_DIR/Library/LaunchAgents/com.sebastienrousseau.ollama.plist" \
  "$(grep -v '^print' "$CALLS/launchctl")" "an agent launchd does not know is bootstrapped"

test_start "ollama_activate_waits_until_the_server_answers"
run_activate FAKE_LOADED=1 FAKE_READY_AFTER=3
assert_equals 0 $? "activate exits 0: $(cat "$WORK/err")"
assert_equals 4 "$(grep -c '^list$' "$CALLS/ollama")" \
  "it polls until the third answer, stops there, then lists the models once"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
