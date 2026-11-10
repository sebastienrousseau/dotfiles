#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# lib/dot/fleet-hosts.sh, the SDK file dot fleet and dot ai share: the
# hosts in fleet.toml, the checks a host passes before any connection, each
# host's agents, and the one SSH call.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$REPO_ROOT/lib/dot/fleet-hosts.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-fleet-hosts.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export DOTFILES_FLEET_HOSTS="$WORK/fleet.toml"

test_start "no_hosts_file_is_no_hosts"
assert_equals "$WORK/fleet.toml" "$(fleet_hosts_file)" "the file DOTFILES_FLEET_HOSTS names"
assert_equals "" "$(fleet_hosts)" "nothing"
assert_equals "" "$(fleet_agents alpha)" "and no agents"

cat >"$WORK/fleet.toml" <<'EOF'
agents = ["claude", "codex"]

[hosts.alpha]
ssh = "u@alpha.test"
profile = "workstation"

[hosts.beta]
ssh = "u@beta.test:2222"
agents = [ "gemini" ]

[other]
agents = ["never"]
EOF

test_start "hosts_in_file_order"
assert_equals "alpha	u@alpha.test	workstation
beta	u@beta.test:2222	" "$(fleet_hosts)" "name, target, profile"

test_start "agents_default_and_per_host"
assert_equals "claude codex" "$(fleet_agents alpha)" "the file's default"
assert_equals "gemini" "$(fleet_agents beta)" "a host's own list"
assert_equals "claude codex" "$(fleet_agents nobody)" "a host with none says nothing of its own"
printf '[hosts.alpha]\nagents = ["claude"]\n' >"$WORK/only-host.toml"
assert_equals "claude|" "$(DOTFILES_FLEET_HOSTS="$WORK/only-host.toml" fleet_agents alpha)|$(DOTFILES_FLEET_HOSTS="$WORK/only-host.toml" fleet_agents beta)" \
  "no default: only the host that names some"

test_start "agent_names_are_plain_ids"
for bad in 'claude; rm -rf ~' '1claude' 'Claude' 'a$(id)'; do
  printf 'agents = ["%s"]\n' "$bad" >"$WORK/bad.toml"
  RC=0
  out="$(DOTFILES_FLEET_HOSTS="$WORK/bad.toml" fleet_agents alpha)" || RC=$?
  assert_equals "1" "$RC" "$bad: refused"
  assert_contains "invalid agent name" "$out" "$bad: says why"
done

test_start "host_checks"
assert_true "fleet_host_check alpha u@alpha.test:22 >/dev/null" "a plain name and target pass"
for pair in ".hidden|u@a" "a/b|u@a" "a;b|u@a" "alpha|-oProxyCommand=x" "alpha|u@a;id" "alpha|u@a b"; do
  RC=0
  out="$(fleet_host_check "${pair%%|*}" "${pair#*|}")" || RC=$?
  assert_equals "1" "$RC" "'$pair': refused"
  assert_contains "invalid" "$out" "'$pair': says why"
done

test_start "one_ssh_call"
mkdir -p "$WORK/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"%s/argv"\ncat >"%s/stdin"\nexit 7\n' "$WORK" "$WORK" >"$WORK/bin/ssh"
chmod +x "$WORK/bin/ssh"
RC=0
printf 'in' | PATH="$WORK/bin:$PATH" DOT_FLEET_CONNECT_TIMEOUT=3 fleet_ssh u@alpha.test 'dot ai check' || RC=$?
assert_equals "7" "$RC" "ssh's status"
assert_equals "-o
BatchMode=yes
-o
ConnectTimeout=3
-o
ServerAliveInterval=15
-o
ServerAliveCountMax=3
-o
StrictHostKeyChecking=accept-new
--
u@alpha.test
dot ai check" "$(cat "$WORK/argv")" "batch mode, the timeout, accept-new, -- before the target"
assert_equals "in" "$(cat "$WORK/stdin")" "the caller's stdin"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
