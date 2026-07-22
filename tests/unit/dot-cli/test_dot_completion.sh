#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Verify `dot completion <shell>` generates completion for each supported
## shell from the command registry, and prints usage with no/unknown args.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"
export REPO_ROOT

DOT="$REPO_ROOT/bin/dot"

test_start "completion_module_exists"
assert_file_exists "$REPO_ROOT/scripts/dot/commands/completion.sh" "completion module should exist"

test_start "completion_bash_emits_complete"
out="$(bash "$DOT" completion bash 2>/dev/null || true)"
assert_contains "complete -W" "$out" "bash completion emits a complete -W directive"

test_start "completion_zsh_emits_compdef"
out="$(bash "$DOT" completion zsh 2>/dev/null || true)"
assert_contains "#compdef dot" "$out" "zsh completion emits a #compdef header"

test_start "completion_fish_emits_complete"
out="$(bash "$DOT" completion fish 2>/dev/null || true)"
assert_contains "complete -c dot" "$out" "fish completion emits complete -c dot"

test_start "completion_nu_emits_extern"
out="$(bash "$DOT" completion nu 2>/dev/null || true)"
assert_contains "export extern dot" "$out" "nushell completion emits export extern dot"

test_start "completion_no_arg_shows_usage"
out="$(bash "$DOT" completion 2>&1 || true)"
assert_contains "Usage: dot completion" "$out" "no-arg completion prints usage"

COMPLETION_MODULE="$REPO_ROOT/scripts/dot/commands/completion.sh"

test_start "completion_module_direct_branches"
out="$(
  set +e
  bash "$COMPLETION_MODULE" completion bash
  bash "$COMPLETION_MODULE" completion zsh
  bash "$COMPLETION_MODULE" completion fish
  bash "$COMPLETION_MODULE" completion nu
  bash "$COMPLETION_MODULE" completion nushell
  bash "$COMPLETION_MODULE" completion
  bash "$COMPLETION_MODULE" completion unknown-shell
  true
)"
assert_contains "export extern dot" "$out" "direct completion module exercises supported shells"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
