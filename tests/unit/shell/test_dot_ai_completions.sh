#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
#
# Completion for the `dot ai` surface (ADR-020). `dot ai <TAB>` offers
# exactly the objects and verbs the ai manifest declares, in bash, zsh and
# fish alike, and `dot ai run <TAB>` offers the agents it lists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ZSH="$REPO_ROOT/share/completions/zsh/_dot"
BASH="$REPO_ROOT/defaults/dot_local/share/bash-completion/completions/dot"
FISH="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish"

# The ai objects and verbs, from the manifest.
WANT="$(python3 -c '
import sys, tomllib
m = tomllib.load(open(sys.argv[1], "rb"))
words = {o["name"] for o in m.get("objects", [])} | {c["verb"] for c in m["commands"] if "object" not in c}
print(" ".join(sorted(words)))' "$REPO_ROOT/plugins/ai/dot-plugin.toml")"

bash_complete() {
  bash --norc --noprofile -c '
    source "$1"; shift
    COMP_WORDS=("$@"); COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    _dot
    printf "%s\n" "${COMPREPLY[@]}"' _ "$BASH" "$@" | LC_ALL=C sort | xargs
}

test_start "completions_bash_ai_verbs"
assert_equals "$WANT" "$(bash_complete dot ai "")" "dot ai <TAB> offers the manifest's objects and verbs"
assert_contains "claude" "$(bash_complete dot ai run "")" "dot ai run <TAB> offers the agents"

test_start "completions_zsh_ai_verbs"
if command -v zsh >/dev/null 2>&1; then
  got="$(zsh -f -c 'source "$1"
    _describe() { local -a a; a=("${(@P)4}"); print -rl -- ${a%%:*}; }
    words=(dot ai ""); CURRENT=3; PREFIX=""; _dot' _ "$ZSH" | LC_ALL=C sort | xargs)"
  assert_equals "$WANT" "$got" "zsh offers the same"
else
  assert_true "true" "zsh not installed; skipped"
fi

test_start "completions_fish_ai_verbs"
if command -v fish >/dev/null 2>&1; then
  got="$(fish --no-config -c 'source $argv[1]; complete -C "dot ai "' "$FISH" | cut -f1 | grep -v '^-' | LC_ALL=C sort | xargs)"
  assert_equals "$WANT" "$got" "fish offers the same"
else
  assert_true "true" "fish not installed; skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
