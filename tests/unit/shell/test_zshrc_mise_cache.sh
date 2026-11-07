#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The cached `mise activate zsh` output must not freeze the PATH of the
# shell that wrote it.
#
# `mise activate` prints `export __MISE_ORIG_PATH='<current PATH>'` and
# `export PATH='<shims>:<current PATH>'`. Cached verbatim, every later
# shell started from that snapshot: tool versions since upgraded, or
# directories of whichever shell (an IDE, an agent, a test) wrote the
# cache. The cache must reference $PATH instead, and expire when mise's
# global config, which shapes the activation script, changes.
#
# Renders dot_zshrc.tmpl with chezmoi and runs the real
# _dotfiles_async_init in `zsh -f` with a sandboxed HOME and a stub mise
# that prints its activation the way mise does.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ZSHRC_TMPL="$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl"

echo "Testing the cached mise activation..."

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ZSH_BIN="$(command -v zsh)"
H="$SANDBOX/home"
LOG="$SANDBOX/mise.log"
mkdir -p "$H/stubs" "$H/.config/mise" "$SANDBOX/render-home" \
  "$SANDBOX/first" "$SANDBOX/second" "$SANDBOX/shims"
: >"$SANDBOX/chezmoi.toml"
: >"$LOG"

env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$ZSHRC_TMPL" >"$H/.zshrc"

# A stub mise that activates the way mise does: it snapshots its own PATH.
cat >"$H/stubs/mise" <<EOF
#!/bin/sh
echo "mise \$*" >>"$LOG"
if [ "\$1" = activate ]; then
  printf "export __MISE_ORIG_PATH='%s'\n" "\$PATH"
  printf "export PATH='%s:%s'\n" "$SANDBOX/shims" "\$PATH"
  echo "export MISE_SHELL=zsh"
fi
EOF
chmod +x "$H/stubs/mise"

# shell <first PATH dir>: a fresh interactive shell that runs the tool init
# and prints its PATH.
shell() {
  env -i HOME="$H" PATH="$H/stubs:$1:/usr/bin:/bin" TERM=dumb \
    "$ZSH_BIN" -f -i -c 'source "$HOME/.zshrc"; _dotfiles_async_init; print -r -- "$PATH"' 2>/dev/null |
    tail -n 1
}

activations() { grep -c '^mise activate' "$LOG"; }
CACHE="$H/.cache/zsh/mise-init.zsh"

test_start "mise_cache_written"
first_path="$(shell "$SANDBOX/first")"
assert_file_exists "$CACHE" "the first shell writes the mise cache"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/first" "$first_path" \
  "the first shell gets the shims ahead of its own PATH"

test_start "mise_cache_does_not_pin_path"
second_path="$(shell "$SANDBOX/second")"
assert_equals "1" "$(activations)" "the second shell reads the cache instead of running mise"
leaked=no
[[ "$second_path" == *"$SANDBOX/first"* ]] && leaked=yes
assert_equals "no" "$leaked" "the second shell does not inherit the first shell's PATH from the cache"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/second" "$second_path" \
  "the second shell gets the shims ahead of its own PATH"

# Backdate the cache and the mise binary, so only a config change can
# expire the cache (a binary newer than the cache already does).
test_start "mise_cache_expires_on_config_change"
touch -t 202001010000 "$CACHE"
touch -t 201901010000 "$H/stubs/mise"
: >"$H/.config/mise/config.toml"
shell "$SANDBOX/second" >/dev/null
assert_equals "2" "$(activations)" "a mise config newer than the cache makes the next shell re-run mise activate"
shell "$SANDBOX/second" >/dev/null
assert_equals "2" "$(activations)" "once rewritten, the cache is used again"

test_start "mise_cache_expires_on_conf_d_change"
touch -t 202001010000 "$CACHE" "$H/.config/mise/config.toml"
touch -t 201901010000 "$H/stubs/mise"
mkdir -p "$H/.config/mise/conf.d"
: >"$H/.config/mise/conf.d/10-local.toml"
shell "$SANDBOX/second" >/dev/null
assert_equals "3" "$(activations)" "a conf.d file newer than the cache also expires it"

print_summary
