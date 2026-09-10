#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Verify `dot completion <shell>` generates completion for each supported
## shell from the command registry, and prints usage with no/unknown args.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"
export REPO_ROOT

# Overridable so the diagnostic path below can be proven to fire against a
# deliberately broken generator, rather than assumed to work.
DOT="${DOT:-$REPO_ROOT/bin/dot}"

# ---------------------------------------------------------------------------
# _emit <shell> — run the generator and keep the evidence.
#
# These captures used to be `"$(bash "$DOT" completion X 2>/dev/null || true)"`,
# which threw away both the exit status and stderr. When this suite failed on
# a macos-14 runner the only thing recoverable from the log was a truncated
# "Actual string" — the bash generator normally emits 81 lines and about 40
# arrived, stopping mid-way through the subcommand `case`. Nothing said
# whether the generator had crashed, been killed, or written a short result,
# because the test had discarded all three answers.
#
# It is not reproducible locally: 20 consecutive generator runs and 5 suite
# runs were clean. So rather than guess at a fix, this keeps what the next
# occurrence needs — status, stderr, and length — and prints it on failure.
# ---------------------------------------------------------------------------
_emit() {
  local shell="$1"
  _emit_err="$(mktemp)"
  _emit_rc=0
  _emit_out="$(bash "$DOT" completion "$shell" 2>"$_emit_err")" || _emit_rc=$?
  _emit_lines="$(printf '%s\n' "$_emit_out" | wc -l | tr -d ' ')"
}

# _emit_diag <label> — dump what a failing generator actually did.
_emit_diag() {
  printf '        | generator exit status: %s\n' "$_emit_rc"
  printf '        | stdout: %s line(s), %s byte(s)\n' \
    "$_emit_lines" "$(printf '%s' "$_emit_out" | wc -c | tr -d ' ')"
  if [[ -s "$_emit_err" ]]; then
    printf '        | stderr:\n'
    sed 's/^/        |   /' "$_emit_err" | head -20
  else
    printf '        | stderr: (empty)\n'
  fi
  printf '        | last 5 lines of stdout:\n'
  printf '%s\n' "$_emit_out" | tail -5 | sed 's/^/        |   /'
  rm -f "$_emit_err"
}

test_start "completion_module_exists"
assert_file_exists "$REPO_ROOT/scripts/dot/commands/completion.sh" "completion module should exist"

test_start "completion_bash_emits_complete"
_emit bash
out="$_emit_out"
if [[ "$out" != *"complete -F _dot_completions"* ]]; then _emit_diag; fi
assert_contains "complete -F _dot_completions" "$out" "bash completion registers the _dot_completions function"
rm -f "$_emit_err"

test_start "completion_zsh_emits_compdef"
_emit zsh
out="$_emit_out"
if [[ "$out" != *"#compdef dot"* ]]; then _emit_diag; fi
assert_contains "#compdef dot" "$out" "zsh completion emits a #compdef header"
rm -f "$_emit_err"

test_start "completion_fish_emits_complete"
_emit fish
out="$_emit_out"
if [[ "$out" != *"complete -c dot"* ]]; then _emit_diag; fi
assert_contains "complete -c dot" "$out" "fish completion emits complete -c dot"
rm -f "$_emit_err"

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
