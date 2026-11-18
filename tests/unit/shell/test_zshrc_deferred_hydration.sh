#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Deferred hydration (mise, atuin, zoxide) in a real interactive zsh.
#
# - It ran in the first precmd, so the first prompt waited for it. It now
#   runs once zle waits for input, after the prompt is drawn, and still
#   before the first command executes.
# - `export DOTFILES_HYDRATED=1` leaked into child shells (tmux panes, IDE
#   terminals, `exec zsh`), which then skipped hydration entirely.
#
# Drives `zsh -i` in a pseudo-terminal (zsh/zpty) with a sandboxed ZDOTDIR
# holding the rendered zshrc and a stub mise whose activation takes 2 s and
# logs each run.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1 ||
  ! zsh -fc 'zmodload zsh/zpty' 2>/dev/null; then
  echo "SKIP: zsh with zsh/zpty and chezmoi are required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ZSH_BIN="$(command -v zsh)"
H="$SANDBOX/home"
LOG="$SANDBOX/mise.log"
mkdir -p "$H/.config/zsh/rc.d" "$SANDBOX/bin" "$SANDBOX/render-home"
: >"$SANDBOX/chezmoi.toml"
: >"$LOG"
env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" >"$H/.config/zsh/.zshrc"
# The deployed config sets noclobber (dot_config/shell/05-core-safety.sh).
printf '%s\n' "PS1='READY> '" 'setopt noclobber' >"$H/.config/zsh/rc.d/99-test.zsh"

# A slow, logging mise activation that sets a variable.
cat >"$SANDBOX/bin/mise" <<EOF
#!/bin/sh
if [ "\$1" = activate ]; then
  echo "sleep 2"
  echo "print -r -- activated >>'$LOG'"
  echo "export MISE_STUB=1"
fi
EOF
chmod +x "$SANDBOX/bin/mise"

# The session: wait for the first prompt and note whether mise had run;
# type a command at once; start a child `zsh -i` and query it.
cat >"$SANDBOX/drive.zsh" <<'EOF'
zmodload zsh/zpty zsh/datetime
H=$1 LOG=$2 BIN=$3 ZSH_BIN=$4
zpty -b S env -i HOME=$H ZDOTDIR=$H/.config/zsh PATH=$BIN:/usr/bin:/bin TERM=xterm $ZSH_BIN -d -i
# expect <pattern>: read until the output matches <pattern> (30 s cap).
expect() {
  local t0=$EPOCHREALTIME chunk
  buf=""
  while [[ $buf != $~1 ]]; do
    zpty -rt S chunk 2>/dev/null && buf+=$chunk
    (( EPOCHREALTIME - t0 > 30 )) && { print "TIMEOUT waiting for $1"; return 1; }
  done
  return 0
}
expect '*READY> *'
print -r -- "at_prompt=$(grep -c activated $LOG)"
# The split marker keeps the echoed command line from matching.
zpty -w S 'print -r -- "FI""RST=${MISE_STUB:-unset}."'
expect '*FIRST=*.*' && print -r -- "first_command=${${buf##*FIRST=}%%.*}"
zpty -w S "$ZSH_BIN -d -i"
expect '*READY> *'
zpty -w S 'print -r -- "CHI""LD=${MISE_STUB:-unset}."'
expect '*CHILD=*.*'
sleep 0.5
print -r -- "child_activations=$(grep -c activated $LOG)"
zpty -w S 'exit'
zpty -w S 'exit'
zpty -d S
EOF

out="$("$ZSH_BIN" -f "$SANDBOX/drive.zsh" "$H" "$LOG" "$SANDBOX/bin" "$ZSH_BIN" 2>&1)"
field() { printf '%s\n' "$out" | sed -n "s/^$1=//p" | tail -n 1; }

test_start "first_prompt_does_not_wait_for_hydration"
assert_equals "0" "$(field at_prompt)" "mise had not run when the first prompt was drawn"

test_start "first_command_sees_mise"
assert_equals "1" "$(field first_command)" "a command typed at the first prompt runs with mise active"

test_start "child_shell_hydrates"
assert_equals "2" "$(field child_activations)" "a child zsh -i of a hydrated shell runs its own hydration"

print_summary
