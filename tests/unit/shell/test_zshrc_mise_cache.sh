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

# A stub mise that activates the way mise does: it snapshots its own PATH,
# quoting a value only when it has to. In a shell where mise is already
# active (its __MISE_SESSION is set), it first undoes that session, unsetting
# the variables it manages, and builds PATH from __MISE_ORIG_PATH.
cat >"$H/stubs/mise" <<EOF
#!/bin/sh
echo "mise \$*" >>"$LOG"
if [ "\$1" = activate ]; then
  base="\$PATH"
  if [ -n "\${__MISE_SESSION:-}" ]; then
    echo "unset JAVA_HOME"
    base="\$__MISE_ORIG_PATH"
  fi
  case "\$base" in
    *[!A-Za-z0-9/_.-]*) printf "export __MISE_ORIG_PATH='%s'\n" "\$base" ;;
    *) printf "export __MISE_ORIG_PATH=%s\n" "\$base" ;;
  esac
  printf "export PATH='%s:%s'\n" "$SANDBOX/shims" "\$base"
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

# A shell where mise is already active (a tmux pane, an IDE terminal, an
# agent's shell) must cache what a new shell would run: not its deactivation
# of the session, nor its own PATH or __MISE_ORIG_PATH.
test_start "mise_cache_from_an_active_shell"
rm -f "$CACHE" "$CACHE.zwc" "$CACHE.bin"
env -i HOME="$H" PATH="$H/stubs:$SANDBOX/install:$SANDBOX/active:/usr/bin:/bin" TERM=dumb \
  __MISE_SESSION=s __MISE_DIFF=d __MISE_ORIG_PATH="$H/stubs:$SANDBOX/orig:/usr/bin:/bin" \
  "$ZSH_BIN" -f -i -c 'source "$HOME/.zshrc"; _dotfiles_async_init' >/dev/null 2>&1
assert_file_exists "$CACHE" "the active shell writes the mise cache"
pinned=none
for p in "$SANDBOX/orig" "$SANDBOX/install" "$SANDBOX/active" "unset JAVA_HOME"; do
  grep -qF -- "$p" "$CACHE" 2>/dev/null && pinned="$p"
done
assert_equals "none" "$pinned" "the cache holds neither the active shell's PATH nor its deactivation"
runs="$(activations)"
fresh_path="$(shell "$SANDBOX/second")"
assert_equals "$runs" "$(activations)" "the next shell reads that cache"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/second" "$fresh_path" \
  "the next shell gets the shims ahead of its own PATH"

# `chezmoi apply` runs prewarm.sh, which caches every tool's init. Writing
# mise's raw activation there would pin PATH again behind the zshrc's back.
test_start "prewarm_does_not_pin_path"
mkdir -p "$SANDBOX/prewarm"
# On a real machine the compiled copy (.zwc) predates prewarm by far more
# than a second, so zsh loads what prewarm wrote; make that so here too.
touch -t 202001010000 "$CACHE.zwc" "$CACHE.bin" 2>/dev/null
# A pinned bash or fish copy from an earlier prewarm must go too: bash never
# reads one, and fish's own _cached_eval writes it unpinned.
mkdir -p "$H/.cache/bash" "$H/.cache/fish"
echo "export PATH='$SANDBOX/stale'" >"$H/.cache/bash/mise-init.bash"
echo "set -gx PATH $SANDBOX/stale" >"$H/.cache/fish/mise-init.fish"
env -i HOME="$H" PATH="$H/stubs:$SANDBOX/prewarm:/usr/bin:/bin" TERM=dumb \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" \
  bash "$REPO_ROOT/scripts/ops/prewarm.sh" >/dev/null 2>&1
after_prewarm="$(shell "$SANDBOX/second")"
leaked=no
[[ "$after_prewarm" == *"$SANDBOX/prewarm"* ]] && leaked=yes
assert_equals "no" "$leaked" "a shell after prewarm does not inherit prewarm's PATH"
assert_contains "$SANDBOX/shims:$H/stubs:$SANDBOX/second" "$after_prewarm" \
  "the shell after prewarm gets the shims ahead of its own PATH"
left=none
for f in "$H/.cache/bash/mise-init.bash" "$H/.cache/fish/mise-init.fish"; do
  [[ -e "$f" ]] && left="$f"
done
assert_equals "none" "$left" "prewarm leaves no bash or fish mise cache"

print_summary
