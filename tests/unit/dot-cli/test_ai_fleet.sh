#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot ai status --fleet and dot ai check --on (plan P1.4), through bin/dot
# in a sandboxed home. A fake ssh runs each command with bash in a home of
# the host's own, where dot answers `ai status --json` and `ai check` from
# fixtures and dot-ai-tui gives each session's cost; a host whose name
# starts with "down" does not answer.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-fleet.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
H="$WORK/home"
mkdir -p "$H/.config/dotfiles" "$H/.local/state/dot/cli/agents/claude" "$WORK/bin" "$WORK/remote"
JQ_DIR="$(dirname "$(command -v jq)")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
rec() { printf '{"schema":"cli/agent-event.v1","time":"%s","agent":"%s","session":"%s","state":"%s","event":"E","cwd":"/w"}\n' "$NOW" "$1" "$2" "$3"; }

# This machine: one claude session, no cost binary.
rec claude here-1 idle >"$H/.local/state/dot/cli/agents/claude/here-1.json"

# A host's home: dot answers from its fixtures; dot-ai-tui from costs.tsv.
remote_home() { # TARGET RECORDS COSTS
  local home="$WORK/remote/$1"
  mkdir -p "$home/bin" "$home/.local/bin"
  printf '%s' "$2" >"$home/records"
  printf '%s' "$3" >"$home/costs.tsv"
  cat >"$home/bin/dot" <<'EOF'
#!/bin/bash
case "$*" in
  "ai status --json") cat "$HOME/records" ;;
  "ai check") echo "AI doctor on $(basename "$HOME")"; exit "$(cat "$HOME/check-rc" 2>/dev/null || echo 3)" ;;
esac
EOF
  printf '#!/bin/bash\n[[ "$*" == "cost --by session --tsv" ]] && cat "$HOME/costs.tsv"\n' >"$home/.local/bin/dot-ai-tui"
  chmod +x "$home/bin/dot" "$home/.local/bin/dot-ai-tui"
}
remote_home u@alpha.test "$(rec claude a-1 blocked)
$(rec codex a-2 running)
" "claude/a-1	2.5
codex/a-2	0.125
"
remote_home u@beta.test "$(rec gemini b-1 idle)
" ""

cat >"$WORK/bin/ssh" <<'EOF'
#!/bin/bash
while [[ "$1" == -* ]]; do [[ "$1" == -- ]] && { shift; break; }; [[ "$1" == -o ]] && shift; shift; done
target="$1" cmd="$2"
printf '%s\n' "$cmd" >"$FLEET_REMOTE/last-cmd"
if [[ "$target" == u@down* ]]; then
  echo "ssh: connect to host ${target#u@} port 22: Connection refused" >&2
  exit 255
fi
home="$FLEET_REMOTE/$target"
HOME="$home" PATH="$home/bin:/usr/bin:/bin" bash -c "$cmd"
EOF
chmod +x "$WORK/bin/ssh"

cat >"$H/.config/dotfiles/fleet.toml" <<'EOF'
[hosts.alpha]
ssh = "u@alpha.test"

[hosts.beta]
ssh = "u@beta.test"

[hosts.down]
ssh = "u@down.test"
EOF

# ai ARGS...: dot ai ARGS... in the sandboxed home; RC, OUT.
ai() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/bin:$JQ_DIR:/usr/bin:/bin" FLEET_REMOTE="$WORK/remote" \
    XDG_STATE_HOME="$H/.local/state" NO_COLOR=1 TERM=dumb LC_ALL=C bash "$REPO_ROOT/bin/dot" ai "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "status_fleet_lists_every_hosts_sessions_with_cost"
ai status --fleet
assert_equals "1" "$RC" "a host that did not answer: exit 1"
assert_contains "HOST" "$OUT" "a HOST column"
assert_contains "COST" "$OUT" "and a COST one"
assert_contains "alpha      claude     blocked" "$OUT" "alpha's blocked session"
assert_contains '$2.50' "$OUT" "with its cost"
assert_contains '$0.13' "$OUT" "the other's, rounded"
assert_contains "beta       gemini     idle" "$OUT" "beta's session"
assert_contains "here-1" "$OUT" "this machine's own"
assert_contains "down: no answer (ssh: connect to host down.test port 22: Connection refused)" "$OUT" "the host that did not answer, and why"
assert_contains "4 sessions on 3 of 4 hosts, 1 blocked" "$OUT" "a summary"

test_start "status_fleet_json"
ai status --fleet --json
lines="$(grep -c '"schema":"ai/fleet-status.v1"' <<<"$OUT")"
assert_equals "4" "$lines" "one line per host, this machine included"
alpha="$(grep '"host":"alpha"' <<<"$OUT")"
assert_equals "true|2|2.5|a-1" "$(jq -r '[.reachable, (.sessions|length), .sessions[0].cost_usd, .sessions[0].event.session] | join("|")' <<<"$alpha")" "alpha's sessions, records and costs"
assert_equals "null" "$(grep '"host":"beta"' <<<"$OUT" | jq -c '.sessions[0].cost_usd')" "no cost known: null"
assert_equals "false|Connection refused" "$(grep '"host":"down"' <<<"$OUT" | jq -r '[.reachable, (.error | capture("(?<x>Connection refused)").x)] | join("|")')" "down: unreachable, and why"

test_start "status_fleet_json_is_fleet_status_v1"
if python3 -c 'import jsonschema' 2>/dev/null; then
  printf '%s\n' "$OUT" >"$WORK/fleet.jsonl"
  RC=0
  python3 -c 'import json, sys
from jsonschema import Draft202012Validator
v = Draft202012Validator(json.load(open(sys.argv[1])))
for line in open(sys.argv[2]):
    v.validate(json.loads(line))' "$REPO_ROOT/schemas/cli/ai-fleet-status.v1.schema.json" "$WORK/fleet.jsonl" || RC=$?
  assert_equals "0" "$RC" "every line validates"
else
  echo "  jsonschema not installed: schema check skipped"
fi

test_start "status_fleet_needs_jq"
RC=0
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/bin:/usr/bin:/bin" NO_COLOR=1 TERM=dumb bash -c '
  source "$1/lib/dot/sdk.sh"; source "$1/lib/dot/fleet-hosts.sh"; source "$1/plugins/ai/libexec/ai/fleet.sh"
  has_command() { [[ "$1" != jq ]] && command -v "$1" >/dev/null; }
  ai_status_fleet' _ "$REPO_ROOT" 2>&1)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "needs jq" "$OUT" "says so"

test_start "status_fleet_refuses_a_bad_host_before_any_connection"
cp "$H/.config/dotfiles/fleet.toml" "$WORK/fleet.toml.good"
printf '[hosts.alpha]\nssh = "u@alpha.test"\n\n[hosts.evil]\nssh = "-oProxyCommand=touch $WORK/pwned"\n' >"$H/.config/dotfiles/fleet.toml"
ai status --fleet
assert_equals "1" "$RC" "exit 1"
assert_contains "evil: no answer (" "$OUT" "the host is named"
assert_contains "invalid" "$OUT" "and why"
assert_contains "alpha      claude     blocked" "$OUT" "the good host still answers"
assert_equals "no" "$([[ -e "$WORK/pwned" ]] && echo yes || echo no)" "and the bad one is never connected to"
cp "$WORK/fleet.toml.good" "$H/.config/dotfiles/fleet.toml"

test_start "status_fleet_with_every_host_answering_exits_0"
printf '[hosts.alpha]\nssh = "u@alpha.test"\n' >"$H/.config/dotfiles/fleet.toml"
ai status --fleet
assert_equals "0" "$RC" "exit 0"
assert_contains "on 2 of 2 hosts" "$OUT" "every host counted"
cp "$WORK/fleet.toml.good" "$H/.config/dotfiles/fleet.toml"

test_start "status_without_fleet_is_this_machine_only"
ai status
assert_equals "no" "$([[ "$OUT" == *alpha* ]] && echo yes || echo no)" "no host is asked"

test_start "check_on_a_host"
ai check --on alpha
assert_equals "3" "$RC" "its exit status"
assert_contains "AI doctor on u@alpha.test" "$OUT" "its output"
assert_equals "dot ai check" "$(cat "$WORK/remote/last-cmd")" "the command it ran"

printf '0\n' >"$WORK/remote/u@beta.test/check-rc"
ai check --on beta
assert_equals "0" "$RC" "a healthy host: exit 0"

test_start "check_on_a_host_not_in_the_fleet"
ai check --on nowhere
assert_equals "1" "$RC" "exit 1"
assert_contains "no host nowhere in $H/.config/dotfiles/fleet.toml" "$OUT" "says so"
printf '[hosts.bad]\nssh = "-oProxyCommand=x"\n' >>"$H/.config/dotfiles/fleet.toml"
ai check --on bad
assert_equals "1" "$RC" "a target ssh would read as an option: exit 1"
assert_contains "invalid ssh target" "$OUT" "refused before connecting"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
