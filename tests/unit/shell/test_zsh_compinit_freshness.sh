#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# The deferred compinit must take the `compinit -C` fast path when the dump
# is fresh (< 24 h) and rebuild only when it is stale or missing.
#
# The old test `[[ -n ${dump}(#qN.mh+24) ]]` needs EXTENDED_GLOB, which the
# config never sets, so it was always true and every shell ran a full
# compinit + compaudit.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

OPTIONS="$REPO_ROOT/defaults/dot_config/zsh/rc.d/30-options.zsh.tmpl"

if ! command -v zsh >/dev/null 2>&1; then
  echo "SKIP: zsh not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d -t zsh-compinit.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# The compinit block has no template directives; extract it verbatim.
sed -n '/^: \${DOTFILES_ENABLE_COMPINIT:=0}/,/^# Colors/p' "$OPTIONS" >"$WORK/block.zsh"

# run_case <dump-state>: fresh | stale | missing. Prints compinit's args.
run_case() {
  local cache="$WORK/cache-$1" dump
  mkdir -p "$cache/zsh"
  rm -f "$WORK/compinit.log"
  XDG_CACHE_HOME="$cache" DOTFILES_ENABLE_COMPINIT=1 zsh -f -c '
    autoload() { :; }
    _dotfiles_add_preexec() { :; }
    _dotfiles_del_preexec() { :; }
    log="$1"
    compinit() { print -r -- "compinit $*" >>"$log"; }
    zcompile() { :; }
    source "$2"
    dump="$_DOTFILES_ZCOMPDUMP"
    case "$3" in
      fresh) : >"$dump" ;;
      stale) : >"$dump"; touch -t 202001010000 "$dump" ;;
    esac
    _deferred_compinit
  ' _ "$WORK/compinit.log" "$WORK/block.zsh" "$1" 2>&1
  cat "$WORK/compinit.log" 2>/dev/null
}

test_start "compinit_block_extracted"
assert_file_contains "$WORK/block.zsh" "_deferred_compinit()" "the compinit block is present"

test_start "compinit_fresh_dump_uses_fast_path"
assert_contains "compinit -C -d" "$(run_case fresh)" "a fresh dump skips the security audit"

test_start "compinit_stale_dump_rebuilds"
out="$(run_case stale)"
if [[ "$out" == *"compinit -d"* && "$out" != *"-C"* ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # stale dump should rebuild, got: $out"
fi

test_start "compinit_missing_dump_rebuilds"
out="$(run_case missing)"
if [[ "$out" == *"compinit -d"* && "$out" != *"-C"* ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # missing dump should rebuild, got: $out"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
