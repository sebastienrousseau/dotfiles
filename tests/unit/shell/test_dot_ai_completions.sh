#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
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

test_start "completions_bash_ai_verbs"
# bash exposes `ai` as a top-level command and lists the verbs in its case arm.
assert_file_contains "$BASH" " ai " "bash completes 'dot ai' as a command"
for v in "${VERBS[@]}"; do
  assert_file_contains "$BASH" "$v" "bash lists 'dot ai $v'"
done

test_start "completions_fish_ai_verbs"
assert_file_contains "$FISH" '-a ai ' "fish completes 'dot ai' as a subcommand"
assert_file_contains "$FISH" "__fish_seen_subcommand_from ai" "fish completes 'dot ai' verbs"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
