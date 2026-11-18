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
      stale | stale-twice) : >"$dump"; touch -t 202001010000 "$dump" ;;
    esac
    _deferred_compinit
    # A second shell after the rebuild (compinit, stubbed here, does not
    # rewrite an unchanged dump).
    [[ "$3" == stale-twice ]] && _deferred_compinit
  ' _ "$WORK/compinit.log" "$WORK/block.zsh" "$1" 2>&1
  cat "$WORK/compinit.log" 2>/dev/null
}

test_start "compinit_block_extracted"
assert_file_contains "$WORK/block.zsh" "_deferred_compinit()" "the compinit block is present"

test_start "compinit_fresh_dump_uses_fast_path"
assert_contains "compinit -C -d" "$(run_case fresh)" "a fresh dump skips the security audit"

test_start "compinit_stale_dump_rebuilds"
out="$(run_case stale)"
if [[ "$out" == *"compinit -i -d"* && "$out" != *"-C"* ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # stale dump should rebuild, got: $out"
fi

test_start "compinit_missing_dump_rebuilds"
out="$(run_case missing)"
if [[ "$out" == *"compinit -i -d"* && "$out" != *"-C"* ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # missing dump should rebuild, got: $out"
fi

# compinit leaves an unchanged dump's mtime alone, so without a refresh
# every shell after the first stale one paid the full compinit + compaudit.
test_start "compinit_rebuild_refreshes_the_dump"
out="$(run_case stale-twice)"
if [[ "$out" == *$'compinit -i -d'*$'\n'"compinit -C -d"* ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # the shell after a rebuild should take the fast path, got: $out"
fi

# The rebuild runs in preexec. With an insecure (world-writable) fpath dir,
# plain compinit asks "Ignore insecure directories ... [y/n]?": in a
# terminal that eats the user's typeahead, under a pty driver it blocks
# (zsh-bench hung the Perf / Baseline job), and without a terminal it
# aborts and leaves completion off. Real compinit here, no stubs.
test_start "compinit_rebuild_skips_insecure_dirs_without_asking"
mkdir -p "$WORK/insecure-fpath" "$WORK/cache-insecure/zsh"
chmod 777 "$WORK/insecure-fpath"
out="$(XDG_CACHE_HOME="$WORK/cache-insecure" DOTFILES_ENABLE_COMPINIT=1 zsh -f -c '
  _dotfiles_add_preexec() { :; }
  _dotfiles_del_preexec() { :; }
  fpath=("$2" $fpath)
  source "$1"
  _deferred_compinit
  print -r -- "compdef=${+functions[compdef]}"
' _ "$WORK/block.zsh" "$WORK/insecure-fpath" </dev/null 2>&1)"
assert_contains "compdef=1" "$out" "completion initialises despite the insecure dir"
assert_output_not_contains "insecure directories" printf '%s' "\"\$out\""

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
