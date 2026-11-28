#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The Ollama LaunchAgent: the plist renders with the real chezmoi against the
# repo's data, and the rendered loader runs under `env -i` with recording
# stubs for launchctl, lsof, ps and dscl. Nothing reaches the real launchd.
# Go template text is single-quoted on purpose (SC2016).
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DEFAULTS="$REPO_ROOT/defaults"
PLIST_TEMPLATE="$DEFAULTS/private_Library/LaunchAgents/com.sebastienrousseau.ollama.plist.tmpl"
LOADER_TEMPLATE="$DEFAULTS/run_onchange_after_34-ollama-launchagent.sh.tmpl"
CHEZMOI_BIN="$(command -v chezmoi 2>/dev/null || true)"
REAL_BASH="${BASH:-$(command -v bash)}"
PY3="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null || true)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ollama-agent.XXXXXX")"
CHILDREN=()
cleanup() {
  for p in ${CHILDREN[@]+"${CHILDREN[@]}"}; do kill "$p" 2>/dev/null || true; done
  rm -rf "$WORK"
}
trap cleanup EXIT
HOME_DIR="$WORK/home"
CALLS="$WORK/calls"
mkdir -p "$HOME_DIR" "$CALLS" "$WORK/dest"
printf '{}\n' >"$WORK/chezmoi.json"

if [[ -z "$CHEZMOI_BIN" || -z "$PY3" ]]; then
  echo "  - skipped: chezmoi or python3 not installed"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# Render a template with the repo's data, a fixed .chezmoi map for <os>, and
# optional extra template code (e.g. an [ollama] override) before it.
render() { # <template> <os> <out> [prelude]
  {
    printf '{{- $_ := set $ "chezmoi" (dict "os" "%s" "homeDir" "/DOT_HOME" "username" "fixture") -}}' "$2"
    printf '%s' "${4:-}"
    cat "$1"
  } | command env -i HOME="$HOME_DIR" PATH=/usr/bin:/bin LANG=C LC_ALL=C \
    "$CHEZMOI_BIN" --config "$WORK/chezmoi.json" --source "$DEFAULTS" \
    --destination "$WORK/dest" --cache "$WORK/cache" \
    --persistent-state "$WORK/state.boltdb" execute-template >"$3" 2>"$3.err"
}
SERVER_OFF='{{- $_ := set $.ollama "server" false -}}'
# Fixed memory, so a render never depends on the host running the test.
MEM_16='{{- $_ := set $.ollama "memory_gb" 16 -}}'
MEM_8='{{- $_ := set $.ollama "memory_gb" 8 -}}'

plist_field() { # <plist> <python expression over d>
  "$PY3" -c 'import plistlib,sys; d=plistlib.load(open(sys.argv[1],"rb")); print(eval(sys.argv[2]))' "$1" "$2"
}

test_start "ollama_agent_plist_runs_the_mise_pin_with_tuned_settings"
render "$PLIST_TEMPLATE" darwin "$WORK/agent.plist" "$MEM_16"
assert_equals 0 $? "plist renders: $(cat "$WORK/agent.plist.err")"
assert_equals "/DOT_HOME/.local/share/mise/shims/ollama serve" \
  "$(plist_field "$WORK/agent.plist" '" ".join(d["ProgramArguments"])')" \
  "the agent serves through the mise shim, so the [ai_tools] pin decides the binary"
assert_equals "1|q8_0|1|1|32768|127.0.0.1:11434" \
  "$(plist_field "$WORK/agent.plist" '"|".join(d["EnvironmentVariables"][k] for k in ("OLLAMA_FLASH_ATTENTION","OLLAMA_KV_CACHE_TYPE","OLLAMA_MAX_LOADED_MODELS","OLLAMA_NUM_PARALLEL","OLLAMA_CONTEXT_LENGTH","OLLAMA_HOST"))')" \
  "the server gets the [ollama] settings"
assert_equals "30m|1|Interactive" \
  "$(plist_field "$WORK/agent.plist" '"|".join((d["EnvironmentVariables"]["OLLAMA_KEEP_ALIVE"], d["EnvironmentVariables"]["MISE_OFFLINE"], d["ProcessType"]))')" \
  "the model stays loaded for keep_alive, mise never downloads at login, and launchd does not throttle the server"
assert_equals "True True" "$(plist_field "$WORK/agent.plist" 'd["RunAtLoad"], d["KeepAlive"]' | tr -d '(),')" \
  "the server starts at login and is restarted if it exits"

test_start "ollama_agent_plist_caps_context_and_keep_alive_on_8gb"
render "$PLIST_TEMPLATE" darwin "$WORK/agent-8gb.plist" "$MEM_8"
assert_equals 0 $? "plist renders: $(cat "$WORK/agent-8gb.plist.err")"
assert_equals "8192|2m|q8_0|1" \
  "$(plist_field "$WORK/agent-8gb.plist" '"|".join(d["EnvironmentVariables"][k] for k in ("OLLAMA_CONTEXT_LENGTH","OLLAMA_KEEP_ALIVE","OLLAMA_KV_CACHE_TYPE","OLLAMA_FLASH_ATTENTION"))')" \
  "an 8 GB Mac gets an 8K context and a 2m keep-alive, keeping the q8_0 cache and flash attention"

test_start "ollama_agent_plist_is_empty_off_macos_or_when_disabled"
render "$PLIST_TEMPLATE" linux "$WORK/agent-linux.plist"
assert_equals "" "$(cat "$WORK/agent-linux.plist")" "no agent outside macOS"
render "$PLIST_TEMPLATE" darwin "$WORK/agent-off.plist" "$SERVER_OFF"
assert_equals "" "$(cat "$WORK/agent-off.plist")" "server = false renders nothing, so chezmoi removes the plist"

test_start "ollama_agent_loader_reruns_on_a_pin_bump"
render "$LOADER_TEMPLATE" darwin "$WORK/loader.sh"
pin="$(sed -n 's/^"aqua:ollama\/ollama" = "\(.*\)"$/\1/p' "$DEFAULTS/.chezmoidata.toml")"
assert_contains "pin $pin" "$(sed -n 4p "$WORK/loader.sh")" "the loader's run_onchange hash covers the ollama pin"

# Stubs: launchctl records; dscl answers the account home; lsof lists the
# FAKE_LISTENERS pids still alive; ps names FAKE_OLLAMA_PID `ollama serve`.
STUBS="$WORK/stubs"
mkdir -p "$STUBS"
mkstub() {
  {
    printf '#!%s\n' "$REAL_BASH"
    cat
  } >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}
mkstub launchctl <<'EOF'
printf '%s\n' "$*" >>"$CALLS/launchctl"
[[ "${1:-}" == bootstrap && "${FAKE_LAUNCHCTL_FAIL:-0}" == 1 ]] && exit 1
exit 0
EOF
mkstub dscl <<'EOF'
printf 'NFSHomeDirectory: %s\n' "${FAKE_ACCOUNT_HOME:-$HOME}"
EOF
mkstub lsof <<'EOF'
for p in ${FAKE_LISTENERS:-}; do kill -0 "$p" 2>/dev/null && echo "$p"; done
exit 0
EOF
mkstub ps <<'EOF'
pid="${*: -1}"
if [[ "$pid" == "${FAKE_OLLAMA_PID:-}" ]]; then
  echo "/DOT_HOME/.local/share/mise/installs/aqua-ollama-ollama/0.40.15/ollama serve"
else
  echo "python3 -m http.server 11434"
fi
EOF
mkstub sleep <<'EOF'
exit 0
EOF
TOOLS="$WORK/tools"
mkdir -p "$TOOLS"
for t in sed grep mkdir id cat; do ln -s "$(command -v "$t")" "$TOOLS/$t"; done

run_loader() { # <script> [VAR=value...]
  local script="$1"
  shift
  rm -f "$CALLS"/*
  command env -i HOME="$HOME_DIR" PATH="$STUBS:$TOOLS" CALLS="$CALLS" "$@" \
    "$REAL_BASH" "$script" >"$WORK/out" 2>"$WORK/err"
}
spawn() { # start a child that stands in for a listener; prints its pid
  sleep 300 &
  CHILDREN+=("$!")
}

test_start "ollama_agent_loader_takes_the_port_from_a_stray_server"
spawn
stray="${CHILDREN[-1]}"
spawn
other="${CHILDREN[-1]}"
run_loader "$WORK/loader.sh" FAKE_LISTENERS="$stray $other" FAKE_OLLAMA_PID="$stray"
assert_equals 0 $? "loader exits 0: $(cat "$WORK/err")"
kill -0 "$stray" 2>/dev/null && alive=yes || alive=no
assert_equals no "$alive" "a stray ollama serve on the port is stopped"
kill -0 "$other" 2>/dev/null && alive=yes || alive=no
assert_equals yes "$alive" "a process that is not ollama serve is left alone"
assert_contains "held by pid $other, not ollama serve" "$(cat "$WORK/err")" "and reported"
uid="$(id -u)"
assert_equals "bootout gui/$uid/com.sebastienrousseau.ollama
bootstrap gui/$uid $HOME_DIR/Library/LaunchAgents/com.sebastienrousseau.ollama.plist
enable gui/$uid/com.sebastienrousseau.ollama" "$(cat "$CALLS/launchctl")" \
  "the agent is reloaded: booted out, bootstrapped and enabled"

test_start "ollama_agent_loader_survives_a_failed_bootstrap"
run_loader "$WORK/loader.sh" FAKE_LAUNCHCTL_FAIL=1
assert_equals 0 $? "a failed bootstrap does not fail chezmoi apply"
assert_contains "could not bootstrap" "$(cat "$WORK/err")" "and is warned about"

test_start "ollama_agent_loader_leaves_launchd_alone_in_a_sandbox_home"
run_loader "$WORK/loader.sh" FAKE_ACCOUNT_HOME="$WORK"
assert_equals 0 $? "a sandboxed apply does not fail"
assert_equals "" "$(cat "$CALLS/launchctl" 2>/dev/null)" "the login GUI domain is untouched"

test_start "ollama_agent_loader_only_unloads_when_disabled"
render "$LOADER_TEMPLATE" darwin "$WORK/loader-off.sh" "$SERVER_OFF"
spawn
kept="${CHILDREN[-1]}"
run_loader "$WORK/loader-off.sh" FAKE_LISTENERS="$kept" FAKE_OLLAMA_PID="$kept"
assert_equals 0 $? "loader exits 0"
assert_equals "bootout gui/$(id -u)/com.sebastienrousseau.ollama" "$(cat "$CALLS/launchctl")" \
  "server = false unloads the agent and bootstraps nothing"
kill -0 "$kept" 2>/dev/null && alive=yes || alive=no
assert_equals yes "$alive" "and leaves any other ollama serve running"

test_start "ollama_agent_loader_is_inert_off_macos"
render "$LOADER_TEMPLATE" linux "$WORK/loader-linux.sh"
assert_equals 0 "$(grep -c launchctl "$WORK/loader-linux.sh")" "no launchctl outside macOS"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
