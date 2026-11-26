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
  env -i HOME="$H" PATH="${SHELL_PATH:-$SANDBOX/bin:/usr/bin:/bin}" SSH_AUTH_SOCK="${1:-}" FAKE_HOST="${FAKE_HOST:-}" \
    zsh -f -i -c '[[ -z $FAKE_HOST ]] || HOST=$FAKE_HOST; source "$1"; print -r -- "$SSH_AUTH_SOCK"' _ "$AGENT_FILE" 2>/dev/null | tail -n 1
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

# GitHub's macOS runners, like many managed Macs, have host names long
# enough that "<dir>/dotfiles-ssh-agent.<host>.sock" passed the 104-byte
# cap on unix socket paths: the bind failed, nothing was live, and every
# shell started an agent again.
test_start "a_long_host_name_still_reuses_one_agent"
: >"$LOG"
FAKE_HOST="$(printf 'a%.0s' {1..80}).example.internal"
first="$(shell)"
second="$(shell)"
assert_equals "1" "$(starts)" "two shells on a long-named host start one agent"
assert_equals "$first" "$second" "and share its socket"
assert_true "[[ -S '$first' ]]" "which is a bound socket"
unset FAKE_HOST

# When even the directory is too long (a deep HOME), the socket moves to a
# private directory under /tmp. A test-only host name keeps it apart from
# any real agent there; it is removed afterwards.
test_start "a_deep_home_moves_the_socket_under_tmp"
: >"$LOG"
H_SAVED="$H"
H="$SANDBOX/$(printf 'd%.0s' {1..70})"
mkdir -p "$H"
FAKE_HOST="zzdotfilestest"
got="$(shell)"
assert_equals "/tmp/dotfiles-ssh-$(id -u)/agent.zzdotfilestest.sock" "$got" "the agent listens under /tmp/dotfiles-ssh-<uid>"
assert_true "[[ -S '$got' ]]" "on a bound socket"
assert_equals "drwx------" "$(ls -ld "/tmp/dotfiles-ssh-$(id -u)" | cut -c1-10)" "in a directory only its owner can enter"
rm -f "$got" "$got.live"
rmdir "/tmp/dotfiles-ssh-$(id -u)" 2>/dev/null || :
H="$H_SAVED"
unset FAKE_HOST

# A new agent gets the default key, with a 2 s bound so a passphrase prompt
# or a stuck agent cannot hang startup. The bound came from timeout(1),
# which macOS before 27 does not ship: there `timeout` was not found, the
# error was discarded, and the key was never added.
cat >"$SANDBOX/bin/ssh-add" <<EOF
case "\$*" in
  *id_ed25519*)
    echo "add \$*" >>"$SANDBOX/add.log"
    [ -e "$SANDBOX/add-hangs" ] && sleep 30
    exit 0 ;;
esac
[ -S "\$SSH_AUTH_SOCK" ] && [ -e "\$SSH_AUTH_SOCK.live" ] && exit 1
exit 2
EOF
chmod +x "$SANDBOX/bin/ssh-add"
mkdir -p "$H/.ssh"
: >"$H/.ssh/id_ed25519"
NO_TIMEOUT_BIN="$(PATH=/usr/bin:/bin path_without "$SANDBOX/nt" timeout gtimeout)"
key_flag=""
[[ "$(uname -s)" == Darwin ]] && key_flag="--apple-use-keychain "

n=0
for case in "with_timeout_binary:/usr/bin:/bin" "without_timeout_binary:$NO_TIMEOUT_BIN"; do
  label="${case%%:*}"
  n=$((n + 1))
  test_start "new_agent_gets_the_default_key_$label"
  : >"$SANDBOX/add.log"
  rm -f "$SANDBOX/add-hangs"
  FAKE_HOST="zzkey$n" SHELL_PATH="$SANDBOX/bin:${case#*:}" shell >/dev/null
  assert_contains "add ${key_flag}$H/.ssh/id_ed25519" "$(cat "$SANDBOX/add.log")" "ssh-add gets the key"

  test_start "a_hanging_ssh_add_does_not_hang_the_shell_$label"
  : >"$SANDBOX/add.log"
  : >"$SANDBOX/add-hangs"
  start=$SECONDS
  FAKE_HOST="zzhang$n" SHELL_PATH="$SANDBOX/bin:${case#*:}" shell >/dev/null
  assert_not_empty "$(cat "$SANDBOX/add.log")" "ssh-add was called"
  assert_equals "true" "$([[ $((SECONDS - start)) -lt 15 ]] && echo true || echo false)" \
    "and the shell starts within its bound, not after ssh-add's 30 s"
done

print_summary
