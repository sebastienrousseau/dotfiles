#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# tmux.conf key table: each prefix key does one thing.
#
# Renders dot_config/tmux/tmux.conf.tmpl with chezmoi, loads it into a
# private tmux server (sandboxed HOME and socket directory) and reads the
# prefix key table back. A later `bind` of the same key silently replaces
# an earlier one, so Prefix+K must stay resize-up next to H/J/L, and the
# kill-server binding must live on a key of its own.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

echo "Testing tmux.conf key bindings..."

if ! command -v tmux >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: tmux and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
TMUX_BIN="$(command -v tmux)"
cleanup() {
  env -i HOME="$SANDBOX/home" TMUX_TMPDIR="$SANDBOX/sock" PATH="$PATH" \
    "$TMUX_BIN" -L keys kill-server >/dev/null 2>&1
  rm -rf "$SANDBOX"
}
trap cleanup EXIT
: >"$SANDBOX/chezmoi.toml"
mkdir -p "$SANDBOX/render-home" "$SANDBOX/home" "$SANDBOX/sock"

test_start "tmux_conf_renders"
rc=0
env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  "$(command -v chezmoi)" --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/tmux/tmux.conf.tmpl" >"$SANDBOX/tmux.conf" || rc=$?
assert_equals "0" "$rc" "tmux.conf renders"

KEYS="$(env -i HOME="$SANDBOX/home" TMUX_TMPDIR="$SANDBOX/sock" PATH="$PATH" TERM=xterm-256color \
  timeout 30 "$TMUX_BIN" -L keys -f "$SANDBOX/tmux.conf" start-server \; list-keys -T prefix 2>/dev/null)"

# key_cmd <key>: the command Prefix+<key> runs, flags and key stripped.
key_cmd() {
  printf '%s\n' "$KEYS" | awk -v k="$1" '($2 == "-T" && $4 == k) || ($2 == "-r" && $5 == k)' |
    sed -E 's/^bind-key +(-r +)?-T prefix +[^ ]+ +//'
}

test_start "tmux_prefix_K_resizes_up"
assert_equals "resize-pane -U 5" "$(key_cmd K)" "Prefix+K resizes the pane up, like H/J/L"

test_start "tmux_prefix_Q_kills_server"
assert_contains "kill-server" "$(key_cmd Q)" "Prefix+Q kills the server (after a confirmation)"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
