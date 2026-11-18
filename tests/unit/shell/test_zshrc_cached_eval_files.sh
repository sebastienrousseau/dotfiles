#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The files _cached_eval leaves in ~/.cache/zsh.
#
# - A regenerated cache must be what the shell sources. zsh loads <cache>.zwc
#   when it is not older than <cache>, to the second, so a cache rewritten
#   within a second of its last compile kept loading the old bytecode.
# - `_cached_eval_clear` also removes the mktemp files a shell killed
#   mid-write leaves behind (<name>.zsh.XXXXXX, <name>.zsh.bin.XXXXXX).
#
# Renders dot_zshrc.tmpl and runs it in `zsh -f -i` with a sandboxed HOME.
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
ZSH_BIN="$(command -v zsh)"
H="$SANDBOX/home"
mkdir -p "$H/bin" "$SANDBOX/render-home"
: >"$SANDBOX/chezmoi.toml"
env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" >"$H/.zshrc"

# zrun <code>: run <code> in an interactive zsh that sourced the zshrc.
zrun() {
  env -i HOME="$H" PATH="$H/bin:/usr/bin:/bin" TERM=dumb \
    "$ZSH_BIN" -f -i -c "source \"\$HOME/.zshrc\"; $1" 2>/dev/null | tail -n 1
}

# tool <value>: a stub init command printing `typeset -g STUB=<value>`.
tool() {
  printf '#!/bin/sh\necho "typeset -g STUB=%s"\n' "$1" >"$H/bin/stubtool"
  chmod +x "$H/bin/stubtool"
}

test_start "regenerated_cache_is_not_shadowed_by_its_zwc"
tool 1
zrun '_cached_eval stub stubtool init; zcompile "$_SHELL_CACHE/stub.zsh"; print -r -- "$STUB"' >/dev/null
tool 2
touch -t 209901010000 "$H/bin/stubtool"
assert_equals "2" "$(zrun '_cached_eval stub stubtool init; print -r -- "$STUB"')" \
  "a shell that regenerates the cache gets the new init, not the old bytecode"

test_start "clear_removes_temp_leftovers"
C="$H/.cache/zsh"
: >"$C/stub.zsh.Ab12Cd"
: >"$C/stub.zsh.bin.Xy34Zw"
: >"$C/unrelated.txt"
zrun '_cached_eval_clear' >/dev/null
left=none
for f in "$C/stub.zsh.Ab12Cd" "$C/stub.zsh.bin.Xy34Zw"; do
  [[ -e "$f" ]] && left="$f"
done
assert_equals "none" "$left" "_cached_eval_clear removes mktemp leftovers"
assert_file_exists "$C/unrelated.txt" "_cached_eval_clear leaves unrelated files alone"

print_summary
