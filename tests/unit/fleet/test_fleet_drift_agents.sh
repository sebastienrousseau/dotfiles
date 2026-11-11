#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot fleet drift show --agents (plan P1.5): every host in fleet.toml says
# what it runs (dot ai inventory show --json) over SSH, and the drift is
# named per host: a version off its pin, hooks missing, an AI policy that
# is not this machine's. A fake ssh answers from each host's fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-fleet-drift-agents.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
H="$WORK/home"
mkdir -p "$H/.config/dotfiles" "$WORK/bin" "$WORK/remote" "$WORK/jq"
ln -s "$(command -v jq)" "$WORK/jq/jq"
POLICY="$H/.config/dotfiles/ai-policy.toml"
printf 'schema = "ai-policy.v1"\n' >"$POLICY"
SHA="$( (shasum -a 256 "$POLICY" 2>/dev/null || sha256sum "$POLICY") | awk '{print $1}')"
OTHER="$(printf '%064d' 7)"

# inventory TARGET SHA DRIFT: what dot ai inventory show --json answers on
# the host; DRIFT is a JSON array of {agent, kind, message}.
inventory() {
  mkdir -p "$WORK/remote/$1"
  jq -cn --arg sha "$2" --argjson drift "$3" \
    '{schema: "ai/inventory.v1", host: "h", time: "2026-11-10T00:00:00Z",
      policy: {path: "~/.config/dotfiles/ai-policy.toml", sha256: (if $sha == "" then null else $sha end)},
      agents: [], drift: $drift}' >"$WORK/remote/$1/inventory.json"
}
inventory u@alpha.test "$SHA" '[]'
inventory u@beta.test "$OTHER" '[{"agent":"codex","kind":"version","message":"codex: 0.1 is off its pin 0.2"},{"agent":"claude","kind":"hooks","message":"claude: hooks missing (dot cli hook install)"}]'
inventory u@gamma.test "" '[]'

cat >"$WORK/bin/ssh" <<'EOF'
#!/bin/bash
while [[ "$1" == -* ]]; do [[ "$1" == -- ]] && { shift; break; }; [[ "$1" == -o ]] && shift; shift; done
target="$1" cmd="$2"
printf '%s\n' "$cmd" >"$FLEET_REMOTE/last-cmd"
if [[ "$target" == u@down* ]]; then
  echo "ssh: connect to host ${target#u@} port 22: Connection refused" >&2
  exit 255
fi
if [[ "$target" == u@old* ]]; then
  echo "dot: 'dot ai inventory show' is not available yet" >&2
  exit 127
fi
[[ "$cmd" == "dot ai inventory show --json" ]] && cat "$FLEET_REMOTE/$target/inventory.json"
EOF
chmod +x "$WORK/bin/ssh"

hosts() { # NAME=TARGET...
  local pair
  : >"$H/.config/dotfiles/fleet.toml"
  for pair in "$@"; do
    printf '[hosts.%s]\nssh = "%s"\n\n' "${pair%%=*}" "${pair#*=}" >>"$H/.config/dotfiles/fleet.toml"
  done
}

# drift ARGS...: dot fleet drift ARGS... in the sandboxed home; RC, OUT.
drift() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/bin:$WORK/jq:/usr/bin:/bin" FLEET_REMOTE="$WORK/remote" \
    NO_COLOR=1 TERM=dumb LC_ALL=C bash "$REPO_ROOT/bin/dot" fleet drift "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "a_fleet_in_step_exits_0"
hosts alpha=u@alpha.test
drift show --agents
assert_equals "0" "$RC" "exit 0"
assert_contains "alpha" "$OUT" "the host"
assert_contains "agents at their pins, hooks wired, this machine's policy" "$OUT" "in step"
assert_equals "dot ai inventory show --json" "$(cat "$WORK/remote/last-cmd")" "what each host is asked"

test_start "each_hosts_drift_is_named"
hosts alpha=u@alpha.test beta=u@beta.test down=u@down.test old=u@old.test
drift show --agents
assert_equals "1" "$RC" "drift: exit 1"
assert_contains "codex: 0.1 is off its pin 0.2" "$OUT" "a version off its pin"
assert_contains "claude: hooks missing (dot cli hook install)" "$OUT" "hooks missing"
assert_contains "beta" "$OUT" "on the host that has them"
assert_contains "AI policy differs from this machine's (dot fleet apply --agents)" "$OUT" "a policy that is not this machine's"
assert_contains "Connection refused" "$OUT" "a host that did not answer, and why"
assert_contains "no inventory (dot config update there)" "$OUT" "a host whose dot has no inventory"
assert_contains "1 of 4 hosts in step" "$OUT" "a summary"

test_start "no_policy_here_is_no_policy_drift"
rm -f "$POLICY"
hosts beta=u@beta.test gamma=u@gamma.test
drift show --agents
assert_equals "no" "$([[ "$OUT" == *"policy differs"* ]] && echo yes || echo no)" "a host's own policy is its business"
assert_contains "1 of 2 hosts in step" "$OUT" "gamma is in step"

test_start "a_policy_here_and_none_there_is_drift"
printf 'schema = "ai-policy.v1"\n' >"$POLICY"
hosts gamma=u@gamma.test
drift show --agents
assert_equals "1" "$RC" "exit 1"
assert_contains "AI policy differs" "$OUT" "the host has none"

test_start "a_bad_host_is_refused_before_any_connection"
hosts 'evil=-oProxyCommand=touch$IFS/tmp/x'
rm -f "$WORK/remote/last-cmd"
drift show --agents
assert_equals "1" "$RC" "exit 1"
assert_contains "invalid" "$OUT" "says why"
assert_equals "no" "$([[ -e "$WORK/remote/last-cmd" ]] && echo yes || echo no)" "no ssh"

test_start "no_jq"
hosts alpha=u@alpha.test
mkdir -p "$WORK/nojq"
for t in bash dirname basename cat awk sed tr mktemp rm uname date hostname head tail grep env ls mkdir; do
  ln -sf "$(command -v "$t")" "$WORK/nojq/$t"
done
RC=0
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/nojq" NO_COLOR=1 TERM=dumb \
  bash "$REPO_ROOT/bin/dot" fleet drift show --agents 2>&1 </dev/null)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "--agents needs jq" "$OUT" "says so"

test_start "no_hosts"
: >"$H/.config/dotfiles/fleet.toml"
drift show --agents
assert_equals "0" "$RC" "exit 0"
assert_contains "no hosts in" "$OUT" "says so"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
