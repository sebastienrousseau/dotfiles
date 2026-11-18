#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Loading the eager alias layer (90-ux-aliases.sh) in a new shell must not
# fork `uname` or rewrite the history file.
#
# - cd.aliases.sh, cd-config.aliases.sh and set_default_aliases ran
#   `uname` at load; $OSTYPE carries the same answer for free.
# - set_default_aliases ran `fc -W`, which rewrote the whole history file
#   from the shell's memory, dropping lines other shells had appended under
#   SHARE_HISTORY. At startup the in-memory history is still empty and zsh
#   writes nothing; a shell that re-sources the layer mid-session (as here:
#   history read, then another shell appends) lost the appended lines.
#
# Renders 90-ux-aliases.sh.tmpl with chezmoi and sources it in `zsh -f -i`
# and `bash` with a sandboxed HOME and a logging fake `uname` on PATH.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
H="$SANDBOX/home"
LOG="$SANDBOX/uname.log"
mkdir -p "$H/Applications" "$SANDBOX/bin" "$SANDBOX/render-home"
: >"$SANDBOX/chezmoi.toml"
: >"$LOG"
ALIASES="$SANDBOX/90-ux-aliases.sh"
env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/shell/90-ux-aliases.sh.tmpl" >"$ALIASES"

REAL_UNAME="$(command -v uname)"
cat >"$SANDBOX/bin/uname" <<EOF
#!/bin/sh
echo "uname \$*" >>"$LOG"
exec "$REAL_UNAME" "\$@"
EOF
chmod +x "$SANDBOX/bin/uname"

HIST="$H/.zsh_history"
printf ': 1700000000:0;echo from-another-shell\n: 1700000001:0;ls\n' >"$HIST"

zsh_out="$(env -i HOME="$H" PATH="$SANDBOX/bin:/usr/bin:/bin" TERM=dumb \
  zsh -f -i -c 'HISTFILE=$HOME/.zsh_history; SAVEHIST=100; HISTSIZE=100; setopt SHARE_HISTORY
    fc -R
    print -r -- ": 1700000002:0;echo appended-meanwhile" >>"$HISTFILE"
    cp "$HISTFILE" "$HISTFILE.expected"
    source "$1"; print -r -- "os=$DOTFILES_OS"; alias app' _ "$ALIASES" 2>/dev/null)"

test_start "zsh_alias_load_runs_no_uname"
assert_equals "0" "$(grep -c '^uname' "$LOG")" "zsh loads the aliases without forking uname"

test_start "zsh_alias_load_keeps_history_file"
assert_true "cmp -s '$HIST.expected' '$HIST'" "the history file keeps a line another shell appended"

test_start "zsh_alias_load_os_and_dir_aliases"
case "$(uname -s)" in
  Darwin) want=Darwin ;;
  Linux) want=Linux ;;
  *) want="$(uname -s)" ;;
esac
assert_contains "os=$want" "$zsh_out" "DOTFILES_OS still names the OS as uname -s does"
assert_contains "cd_with_history \"\${APP_DIR}\"" "$zsh_out" "dir aliases still read their variable when used"

: >"$LOG"
env -i HOME="$H" PATH="$SANDBOX/bin:/usr/bin:/bin" TERM=dumb \
  bash -c 'source "$1"' _ "$ALIASES" >/dev/null 2>&1
test_start "bash_alias_load_runs_no_uname"
assert_equals "0" "$(grep -c '^uname' "$LOG")" "bash loads the aliases without forking uname"

print_summary
