#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for scripts/dot/commands/completion.sh: the generated
# completion for each supported shell is asserted against the canonical
# `_dot_help_specs` registry in bin/dot — commands appear, subcommands are
# split parent/child, and the quoting-hostile characters are stripped.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

COMPLETION="$REPO_ROOT/scripts/dot/commands/completion.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

OUTF="$DOTFILES_COV_TMPDIR/completion.txt"
ERRF="$DOTFILES_COV_TMPDIR/completion-err.txt"

# completion <shell> — `dot completion <shell>`: $1 is the command name.
completion() {
  bash "$COMPLETION" completion "$@" >"$OUTF" </dev/null
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }

test_start "script_exists_and_parses"
assert_file_exists "$COMPLETION" "completion.sh must exist"
assert_true "bash -n '$COMPLETION'" "valid bash syntax"

test_start "no_shell_prints_usage"
completion
assert_equals 0 "$RC" "rc"
out_has "Usage: dot completion <bash|zsh|fish|nu>" "usage"

test_start "help_prints_usage"
completion --help
assert_equals 0 "$RC" "rc"
out_has "Generate shell completion" "usage body"

test_start "unknown_shell_fails_with_a_hint"
# stderr to its own file (never merged into stdout): redirecting it away
# would take the child's xtrace with it.
bash "$COMPLETION" completion tcsh >"$OUTF" 2>"$ERRF" </dev/null
RC=$?
[[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
assert_equals 1 "$RC" "rc"
assert_file_contains "$ERRF" "unknown shell 'tcsh'" "error names the shell"
assert_file_contains "$ERRF" "want: bash|zsh|fish|nu" "hint"

test_start "bash_completion_is_a_completion_function"
completion bash
assert_equals 0 "$RC" "rc"
out_has "# dot bash completion" "header comment"
# The bash generator emits a completion FUNCTION, not a flat
# `complete -W` word list, so that bash gets the same parent/child
# subcommand completion zsh and fish already had. The top-level command
# list still comes from the registry, via the `commands=` assignment.
out_has "_dot_completions()" "completion function"
out_has "commands='" "registry-derived word list"
out_has "doctor" "a real command is present"
out_has "complete -F _dot_completions dot" "ends with the dot binding"
# Parent/child arms are what the flat word list could not express.
out_has "agent)" "a parent command has a subcommand arm"

test_start "zsh_completion_is_a_compdef_function"
completion zsh
assert_equals 0 "$RC" "rc"
out_has "#compdef dot" "compdef header"
out_has "_describe" "describe call"
out_has "'doctor:" "name:description pair"
# Only the trailing `_dot "$@"` call may carry a double quote: every
# description has its quoting-hostile characters stripped.
assert_equals "1" "$(grep -c '\"' "$OUTF")" "descriptions carry no double quotes"

test_start "fish_completion_covers_commands_and_subcommands"
completion fish
assert_equals 0 "$RC" "rc"
out_has "complete -c dot -f" "reset line"
out_has "__fish_use_subcommand" "top-level completions"
out_has "__fish_seen_subcommand_from" "subcommand completions"
out_has "-a doctor" "a real command"

test_start "nu_completion_declares_an_extern"
completion nu
assert_equals 0 "$RC" "rc"
out_has "export extern dot" "extern declaration"
out_has "def dot_commands" "completer function"
out_has 'value: "doctor"' "a real command"

test_start "nushell_is_an_accepted_alias_for_nu"
completion nushell
assert_equals 0 "$RC" "rc"
out_has "export extern dot" "same generator"

test_start "every_shell_lists_the_same_command_set"
completion bash
bash_names="$(grep -o "commands='[^']*'" "$OUTF" | sed "s/commands='//; s/'$//" | tr ' ' '\n' | sort -u | grep -c .)"
completion zsh
zsh_names="$(grep -c "^    '" "$OUTF")"
assert_equals "$bash_names" "$zsh_names" "bash and zsh agree on the command count"
assert_true "[[ $bash_names -gt 10 ]]" "the registry is non-trivial"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
