#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Completion parity for the `dot ai` surface. Every canonical AI subcommand
# must be tab-completable in zsh, bash, and fish, so the three completion
# files cannot drift from the command surface in scripts/dot/commands/ai.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ZSH="$REPO_ROOT/share/completions/zsh/_dot"
BASH="$REPO_ROOT/defaults/dot_local/share/bash-completion/completions/dot"
FISH="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl"

# Canonical AI verbs (mirror the dispatch in scripts/dot/commands/ai.sh).
VERBS=(run chat tools install serve cost login doctor ask delegate)

test_start "completions_zsh_ai_verbs"
for v in "${VERBS[@]}"; do
  assert_file_contains "$ZSH" "'$v:" "zsh completes 'dot ai $v'"
done

# bash: load the completion and ask it, the way readline would.
# bash_complete <words...>: COMPREPLY for completing the last word.
bash_complete() {
  # shellcheck disable=SC2016
  bash --norc --noprofile -c '
    source "$1"; shift
    COMP_WORDS=("$@"); COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    _dot_completions
    printf "%s\n" "${COMPREPLY[@]}" | sort | tr "\n" " "' _ "$BASH" "$@"
}

test_start "completions_bash_ai_verbs"
assert_equals "$(printf '%s\n' "${VERBS[@]}" | sort | tr '\n' ' ')" "$(bash_complete dot ai "")" "dot ai <TAB> offers every verb"

test_start "completions_bash_top_level_ai"
assert_equals "ai ai-query ai-setup aider " "$(bash_complete dot ai)" "dot ai<TAB> offers the ai commands"

# Commands whose subcommands were registered without a top-level entry
# never showed up at `dot <TAB>`.
test_start "completions_bash_top_level_has_every_parent"
assert_equals "agent agents |aliases |patterns |registry " \
  "$(bash_complete dot agent)|$(bash_complete dot alias)|$(bash_complete dot pat)|$(bash_complete dot reg)" \
  "agents, aliases, patterns and registry complete at the top level"

test_start "completions_fish_ai_verbs"
assert_file_contains "$FISH" '-a ai ' "fish completes 'dot ai' as a subcommand"
assert_file_contains "$FISH" "__fish_seen_subcommand_from ai" "fish completes 'dot ai' verbs"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
