#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot fleet apply --agents (plan P1.4): each host in fleet.toml gets its
# agents at their pins, this machine's AI policy (checked there before it
# replaces the old one), the agent hooks, then dot doctor. A fake ssh runs
# the remote command with bash in a home of the host's own, where dot is a
# stub that records each call, so the command's shell is what is tested.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-fleet-agents.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done
H="$WORK/home"
mkdir -p "$H/.config/dotfiles" "$WORK/bin" "$WORK/remote"

# ssh: the host's home is $WORK/remote/<target>; its dot records each call
# and fails the policy check when the policy names the mode "bad".
cat >"$WORK/bin/ssh" <<'EOF'
#!/bin/bash
while [[ "$1" == -* ]]; do [[ "$1" == -- ]] && { shift; break; }; [[ "$1" == -o ]] && shift; shift; done
target="$1" cmd="$2"
home="$FLEET_REMOTE/$target"
mkdir -p "$home/bin"
cat >"$home/bin/dot" <<'DOT'
#!/bin/bash
printf 'dot %s\n' "$*" >>"$HOME/calls"
if [[ "$*" == "ai policy check --policy "* ]]; then
  ! grep -q 'mode = "bad"' "$5"
fi
DOT
chmod +x "$home/bin/dot"
HOME="$home" PATH="$home/bin:/usr/bin:/bin" bash -c "$cmd"
EOF
chmod +x "$WORK/bin/ssh"

cat >"$H/.config/dotfiles/fleet.toml" <<'EOF'
agents = ["claude", "codex"]

[hosts.alpha]
ssh = "u@alpha.test"

[hosts.beta]
ssh = "u@beta.test"
agents = [ "gemini" ]
EOF
POLICY="$H/.config/dotfiles/ai-policy.toml"
printf 'schema = "ai-policy.v1"\ndefault_mode = "ask"\n# a "quoted" $HOME line\n' >"$POLICY"

# fleet ARGS...: dot fleet apply ARGS... in the sandboxed home; RC, OUT.
fleet() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$WORK/bin:/usr/bin:/bin" FLEET_REMOTE="$WORK/remote" \
    NO_COLOR=1 TERM=dumb bash "$REPO_ROOT/bin/dot" fleet apply "$@" 2>&1 </dev/null)" || RC=$?
}
calls() { cat "$WORK/remote/$1/calls" 2>/dev/null; }

test_start "agents_provision_every_host"
fleet --agents
assert_equals "0" "$RC" "exit 0"
assert_equals "dot config update
dot ai install --yes claude
dot ai install --yes codex
dot ai policy check --policy $WORK/remote/u@alpha.test/.config/dotfiles/ai-policy.toml.new
dot cli hook install
dot doctor" "$(calls u@alpha.test)" "alpha: update, the default agents, the policy, the hooks, doctor"
assert_contains "dot ai install --yes gemini" "$(calls u@beta.test)" "beta: its own agents"
assert_equals "no" "$(grep -q 'install --yes claude' "$WORK/remote/u@beta.test/calls" && echo yes || echo no)" "and not the default ones"

test_start "the_policy_arrives_whole_and_private"
assert_equals "$(cat "$POLICY")" "$(cat "$WORK/remote/u@alpha.test/.config/dotfiles/ai-policy.toml")" "byte for byte"
# GNU stat first: on Linux, stat -f is the file system's status, and works.
mode="$(stat -c %a "$WORK/remote/u@alpha.test/.config/dotfiles/ai-policy.toml" 2>/dev/null ||
  stat -f %Lp "$WORK/remote/u@alpha.test/.config/dotfiles/ai-policy.toml")"
assert_equals "600" "$mode" "0600"

test_start "a_policy_the_host_refuses_keeps_its_old_one"
printf 'old\n' >"$WORK/remote/u@alpha.test/.config/dotfiles/ai-policy.toml"
printf 'mode = "bad"\n' >"$POLICY"
rm -f "$WORK/remote/u@alpha.test/calls"
fleet --agents --host alpha
assert_equals "1" "$RC" "the host fails"
assert_equals "old" "$(cat "$WORK/remote/u@alpha.test/.config/dotfiles/ai-policy.toml")" "its policy is the old one"
assert_equals "no" "$(grep -q 'hook install' "$WORK/remote/u@alpha.test/calls" && echo yes || echo no)" "and nothing after the check ran"

test_start "no_local_policy_pushes_none"
rm -f "$POLICY"
rm -rf "$WORK/remote"
fleet --agents --host alpha
assert_equals "0" "$RC" "exit 0"
assert_equals "no" "$(grep -q 'policy check' "$WORK/remote/u@alpha.test/calls" && echo yes || echo no)" "no policy step"

test_start "dry_run_names_each_hosts_steps"
printf 'schema = "ai-policy.v1"\n' >"$POLICY"
rm -rf "$WORK/remote"
fleet --agents --dry-run
assert_contains "dot ai install --yes gemini" "$OUT" "beta's agents"
assert_contains "ai-policy.toml (sha256 " "$OUT" "the policy by its digest"
assert_equals "no" "$([[ -d "$WORK/remote" ]] && echo yes || echo no)" "and no ssh"

test_start "bad_agent_names_and_cmd_with_agents_are_refused"
printf 'agents = ["claude; rm -rf ~"]\n[hosts.alpha]\nssh = "u@alpha.test"\n' >"$H/.config/dotfiles/fleet.toml"
fleet --agents --dry-run
assert_equals "1" "$RC" "a bad agent name: exit 1"
assert_contains "invalid agent name" "$OUT" "says so"
fleet --agents --cmd uptime --dry-run
assert_equals "1" "$RC" "--cmd and --agents: exit 1"
assert_contains "--agents and --cmd" "$OUT" "says they do not mix"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
