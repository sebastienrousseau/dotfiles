#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Unit tests for Wave 1: dot_zshenv PATH entries
#
# Sources defaults/dot_zshenv in `zsh -f` with a sandboxed HOME and a
# clean environment, then checks the exported XDG dirs, ZDOTDIR and PATH.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ZSHENV="$REPO_ROOT/defaults/dot_zshenv"

echo "Testing Wave 1: dot_zshenv PATH entries..."

if ! command -v zsh >/dev/null 2>&1; then
  echo "SKIP: zsh not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ZSH_BIN="$(command -v zsh)"
BASE_PATH="/usr/bin:/bin"

# zshenv_eval <home> <path> <times> <expr>: source dot_zshenv <times>
# times in `zsh -f` with only HOME and PATH set, then print <expr>.
zshenv_eval() {
  env -i HOME="$1" PATH="$2" ZSHENV="$ZSHENV" TIMES="$3" \
    "$ZSH_BIN" -f -c 'repeat $TIMES source "$ZSHENV"; print -r -- '"$4"
}

# Count how often <dir> appears as a PATH entry.
count_entries() {
  local dir="$1" path_value="$2" n=0 entry
  local IFS=:
  for entry in $path_value; do
    [[ "$entry" == "$dir" ]] && n=$((n + 1))
  done
  echo "$n"
}

# --- XDG base directories and ZDOTDIR ---

home_plain="$SANDBOX/plain"
mkdir -p "$home_plain"

test_start "zshenv_sources_cleanly"
rc=0
zshenv_eval "$home_plain" "$BASE_PATH" 1 'ok' >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "dot_zshenv sources without error in zsh -f"

for pair in XDG_CONFIG_HOME:.config XDG_CACHE_HOME:.cache \
  XDG_DATA_HOME:.local/share XDG_STATE_HOME:.local/state ZDOTDIR:.config/zsh; do
  var="${pair%%:*}"
  rel="${pair#*:}"
  test_start "zshenv_sets_${var}"
  assert_equals "$home_plain/$rel" "$(zshenv_eval "$home_plain" "$BASE_PATH" 1 "\$$var")" \
    "$var is exported as \$HOME/$rel"
done

test_start "zshenv_xdg_exported"
assert_equals "$home_plain/.config" \
  "$(zshenv_eval "$home_plain" "$BASE_PATH" 1 '$(/usr/bin/env | /usr/bin/sed -n "s/^XDG_CONFIG_HOME=//p")')" \
  "XDG_CONFIG_HOME reaches child processes"

# --- ~/.local/bin ---

home_bin="$SANDBOX/withbin"
mkdir -p "$home_bin/.local/bin"

test_start "zshenv_local_bin_prepended"
path_out="$(zshenv_eval "$home_bin" "$BASE_PATH" 1 '$PATH')"
order="after"
[[ ":$path_out:" == *":$home_bin/.local/bin:"*"$BASE_PATH:"* ]] && order="before"
assert_equals "before" "$order" "the ~/.local/bin dir is put on PATH ahead of the system dirs"

test_start "zshenv_local_bin_idempotent"
path_out="$(zshenv_eval "$home_bin" "$BASE_PATH" 3 '$PATH')"
assert_equals "1" "$(count_entries "$home_bin/.local/bin" "$path_out")" \
  "sourcing three times adds ~/.local/bin once"

test_start "zshenv_local_bin_already_on_path"
path_out="$(zshenv_eval "$home_bin" "$BASE_PATH:$home_bin/.local/bin" 1 '$PATH')"
assert_equals "1" "$(count_entries "$home_bin/.local/bin" "$path_out")" \
  "the ~/.local/bin dir already on PATH is not added again"

test_start "zshenv_local_bin_dir_check"
path_out="$(zshenv_eval "$home_plain" "$BASE_PATH" 1 '$PATH')"
assert_equals "0" "$(count_entries "$home_plain/.local/bin" "$path_out")" \
  "a missing ~/.local/bin is not put on PATH"

# --- /opt/homebrew/bin (host-dependent: the path is fixed) ---

path_out="$(zshenv_eval "$home_plain" "$BASE_PATH" 3 '$PATH')"
if [[ -d /opt/homebrew/bin ]]; then
  test_start "zshenv_homebrew_prepended_once"
  assert_equals "1" "$(count_entries /opt/homebrew/bin "$path_out")" \
    "/opt/homebrew/bin is on PATH once after three sources"
  test_start "zshenv_homebrew_already_on_path"
  path_out="$(zshenv_eval "$home_plain" "$BASE_PATH:/opt/homebrew/bin" 1 '$PATH')"
  assert_equals "1" "$(count_entries /opt/homebrew/bin "$path_out")" \
    "/opt/homebrew/bin already on PATH is not added again"
else
  test_start "zshenv_homebrew_dir_check"
  assert_equals "0" "$(count_entries /opt/homebrew/bin "$path_out")" \
    "/opt/homebrew/bin is not put on PATH when it does not exist"
fi

# --- No heavy init: zshenv runs for every zsh, scripts included ---

stub_dir="$SANDBOX/stubs"
mkdir -p "$stub_dir"
for tool in mise starship zoxide atuin fnm direnv brew pyenv rbenv nodenv conda nvm; do
  printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$tool" "$SANDBOX/init.log" >"$stub_dir/$tool"
  chmod +x "$stub_dir/$tool"
done
: >"$SANDBOX/init.log"

test_start "zshenv_no_heavy_init"
zshenv_eval "$home_bin" "$stub_dir:$BASE_PATH" 1 'ok' >/dev/null 2>&1
assert_empty "$(cat "$SANDBOX/init.log")" "sourcing dot_zshenv runs no tool init (mise, starship, fnm, ...)"

echo ""
echo "Wave 1 dot_zshenv PATH tests completed."
print_summary
