#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# rc.d/05-ssh-agent.zsh must reuse one ssh-agent across shells.
#
# With SSH_AUTH_SOCK empty, it ran a bare `ssh-agent -s` in every
# interactive shell, leaking an agent process per shell. It now starts an
# agent on a fixed socket only when nothing answers there.
#
# Sources the file in `zsh -f -i` with a fake ssh-agent (logs each start,
# binds the socket, marks it live) and a fake ssh-add (exit 2 unless the
# socket is live), so no real agent is started or touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v zsh >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: zsh and python3 are required"
  echo "RESULTS:0:0:0"
  exit 0
fi

# The fake agent binds its socket with the python3 found here: the shells
# run with PATH limited to /usr/bin:/bin, where a runner's python3 may not
# be (GitHub's macOS images), and then no socket is ever bound.
PYTHON3="$(command -v python3)"
# A short directory: unix socket paths are capped near 104 bytes.
SANDBOX="$(mktemp -d /tmp/ssha.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT
H="$SANDBOX/h"
LOG="$SANDBOX/agent.log"
mkdir -p "$H" "$SANDBOX/bin"
: >"$LOG"
AGENT_FILE="$REPO_ROOT/defaults/dot_config/zsh/rc.d/05-ssh-agent.zsh"

cat >"$SANDBOX/bin/ssh-agent" <<EOF
#!/bin/sh
# Fake: -s [-a sock]; without -a it makes up a socket, as ssh-agent does.
sock="$SANDBOX/random.\$\$.sock"
[ "\$2" = -a ] && sock="\$3"
[ -e "\$sock" ] && exit 1
echo "start \$sock" >>"$LOG"
"$PYTHON3" -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "\$sock"
: >"\$sock.live"
echo "SSH_AUTH_SOCK=\$sock; export SSH_AUTH_SOCK;"
echo "SSH_AGENT_PID=4242; export SSH_AGENT_PID;"
EOF
cat >"$SANDBOX/bin/ssh-add" <<'EOF'
#!/bin/sh
[ -S "$SSH_AUTH_SOCK" ] && [ -e "$SSH_AUTH_SOCK.live" ] && exit 1
exit 2
EOF
chmod +x "$SANDBOX/bin/ssh-agent" "$SANDBOX/bin/ssh-add"

# shell [SSH_AUTH_SOCK]: an interactive shell sourcing the file; prints the
# SSH_AUTH_SOCK it ends up with.
shell() {
  env -i HOME="$H" PATH="$SANDBOX/bin:/usr/bin:/bin" SSH_AUTH_SOCK="${1:-}" \
    zsh -f -i -c 'source "$1"; print -r -- "$SSH_AUTH_SOCK"' _ "$AGENT_FILE" 2>/dev/null | tail -n 1
}
starts() { grep -c '^start' "$LOG"; }

test_start "ssh_agent_started_once"
first="$(shell)"
second="$(shell)"
third="$(shell)"
assert_equals "1" "$(starts)" "three shells start one agent"
assert_not_empty "$first" "the first shell exports the agent's socket"
assert_equals "$first" "$second" "the second shell uses the first shell's agent"
assert_equals "$first" "$third" "so does the third"

test_start "ssh_agent_restarted_when_dead"
rm -f "$first.live"
again="$(shell)"
assert_equals "2" "$(starts)" "a socket nothing answers on gets a new agent"
assert_equals "$first" "$again" "on the same socket"

test_start "ssh_agent_existing_sock_kept"
assert_equals "/elsewhere/agent.sock" "$(shell /elsewhere/agent.sock)" "a set SSH_AUTH_SOCK is left alone"
assert_equals "2" "$(starts)" "and no agent is started"

print_summary
