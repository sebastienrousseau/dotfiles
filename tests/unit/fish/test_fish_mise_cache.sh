#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The cached `mise activate fish` output must not freeze the PATH of the
# shell that wrote it, as tests/unit/shell/test_zshrc_mise_cache.sh asks of
# zsh.
#
# `mise activate fish` prints `set -gx __MISE_ORIG_PATH <PATH>` and
# `set -gx PATH <shims> <PATH>`; fish's _cached_eval stored that verbatim,
# and init.fish never regenerated a cache that existed, so every fish shell
# started from the PATH of whichever shell (a test, prewarm, an agent) first
# wrote it, even after mise was upgraded or its config changed.
#
# Renders init.fish.tmpl with chezmoi and runs the real _dotfiles_async_init
# in fish with a sandboxed HOME and a stub mise that activates the way mise
# does.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

INIT_TMPL="$REPO_ROOT/defaults/dot_config/fish/conf.d/init.fish.tmpl"
FUNCS="$REPO_ROOT/defaults/dot_config/fish/functions"

echo "Testing fish's cached mise activation..."

if ! command -v fish >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: fish and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
FISH_BIN="$(command -v fish)"
H="$SANDBOX/home"
LOG="$SANDBOX/mise.log"
mkdir -p "$H/stubs" "$H/.config/mise" "$H/.config/fish/conf.d" "$H/.config/fish/functions" \
  "$SANDBOX/render-home" "$SANDBOX/first" "$SANDBOX/second" "$SANDBOX/shims"
: >"$SANDBOX/chezmoi.toml"
: >"$LOG"

env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$INIT_TMPL" >"$H/.config/fish/conf.d/init.fish"
for f in "$FUNCS"/_cached_eval*.fish; do
  cp "$f" "$H/.config/fish/functions/${f##*/}"
done

# A stub mise that activates the way mise does: it snapshots its own PATH.
# In a shell where mise is already active (its __MISE_SESSION is set), it
# first undoes that session and builds PATH from __MISE_ORIG_PATH.
cat >"$H/stubs/mise" <<EOF
#!/bin/sh
echo "mise \$*" >>"$LOG"
if [ "\$1" = activate ]; then
  base="\$PATH"
  if [ -n "\${__MISE_SESSION:-}" ]; then
    echo "set -e JAVA_HOME"
    base="\$__MISE_ORIG_PATH"
  fi
  # Builtins only: like mise, the stub needs nothing from PATH.
  IFS=:
  set -f
  set -- \$base
  IFS=' '
  words="\$*"
  echo "set -gx __MISE_ORIG_PATH \$words"
  echo "set -gx PATH $SANDBOX/shims \$words"
fi
EOF
chmod +x "$H/stubs/mise"

# shell <first PATH dir> [env...]: a fresh interactive fish that runs the
# tool init and prints its PATH.
shell() {
  local dir=$1
  shift
  env -i HOME="$H" PATH="$H/stubs:$dir:/usr/bin:/bin" TERM=dumb "$@" \
    "$FISH_BIN" --no-config -i -c '
      set fish_function_path $HOME/.config/fish/functions $fish_function_path
      source $HOME/.config/fish/conf.d/init.fish
      _dotfiles_async_init
      string join : $PATH' 2>/dev/null | tail -n 1
}

activations() { grep -c '^mise activate' "$LOG"; }
CACHE="$H/.cache/fish/mise-init.fish"

test_start "fish_mise_cache_written"
first_path="$(shell "$SANDBOX/first")"
assert_file_exists "$CACHE" "the first shell writes the mise cache"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/first" "$first_path" \
  "the first shell gets the shims ahead of its own PATH"

test_start "fish_mise_cache_does_not_pin_path"
second_path="$(shell "$SANDBOX/second")"
assert_equals "1" "$(activations)" "the second shell reads the cache instead of running mise"
leaked=no
[[ "$second_path" == *"$SANDBOX/first"* ]] && leaked=yes
assert_equals "no" "$leaked" "the second shell does not inherit the first shell's PATH from the cache"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/second" "$second_path" \
  "the second shell gets the shims ahead of its own PATH"

test_start "fish_mise_cache_expires_with_the_binary"
touch -t 202001010000 "$CACHE"
touch -t 202101010000 "$H/stubs/mise"
shell "$SANDBOX/second" >/dev/null
assert_equals "2" "$(activations)" "a mise binary newer than the cache makes the next shell re-run mise activate"

test_start "fish_mise_cache_expires_on_config_change"
touch -t 202001010000 "$CACHE"
touch -t 201901010000 "$H/stubs/mise"
mkdir -p "$H/.config/mise/conf.d"
: >"$H/.config/mise/conf.d/10-local.toml"
shell "$SANDBOX/second" >/dev/null
assert_equals "3" "$(activations)" "a mise config newer than the cache expires it"
shell "$SANDBOX/second" >/dev/null
assert_equals "3" "$(activations)" "once rewritten, the cache is used again"

test_start "fish_mise_cache_from_an_active_shell"
rm -f "$CACHE"
shell "$SANDBOX/active" __MISE_SESSION=s __MISE_DIFF=d \
  __MISE_ORIG_PATH="$H/stubs:$SANDBOX/orig:/usr/bin:/bin" >/dev/null
assert_file_exists "$CACHE" "the active shell writes the mise cache"
pinned=none
for p in "$SANDBOX/orig" "$SANDBOX/active" "JAVA_HOME"; do
  grep -qF -- "$p" "$CACHE" 2>/dev/null && pinned="$p"
done
assert_equals "none" "$pinned" "the cache holds neither the active shell's PATH nor its deactivation"
fresh_path="$(shell "$SANDBOX/second")"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/second" "$fresh_path" \
  "the next shell gets the shims ahead of its own PATH"

print_summary
