#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/dot/commands/patterns.sh — the AI
# steering-pattern manager: list, view (with and without `glow`), edit
# (through a recording $EDITOR), the missing-name errors, the
# not-found path and the usage fallback. Patterns live in the sandbox
# XDG_CONFIG_HOME, so no real ~/.config is touched and no editor opens.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

PATTERNS="$REPO_ROOT/scripts/dot/commands/patterns.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Substring refutation on an already-captured string. The framework's
# assert_output_not_contains re-runs its arguments through `eval`, so
# feeding captured output back in breaks on any shell metacharacter the
# program happened to print.
_refute_contains() { # <needle> <haystack> <msg>
  if [[ "$2" != *"$1"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $3"
    return 0
  fi
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $3"
  printf '%b\n' "    Should not contain: '$1'"
  return 1
}

PATTERN_DIR="$XDG_CONFIG_HOME/ai/patterns"
LOG="$DOTFILES_COV_TMPDIR/patterns.log"
: >"$LOG"

# A PATH with no `glow` at all. The host's may carry a mise shim for it,
# which would take the glow branch (and fail on an untrusted config)
# where this test wants the plain `cat` fallback.
NOGLOW="$DOTFILES_COV_TMPDIR/noglow"
mkdir -p "$NOGLOW"
for _t in bash cat ls sed mkdir printf echo tr head tail wc date uname \
  hostname tput dirname basename grep awk sort id stat find; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$NOGLOW/$_t"
done

_run() { # [args…] — runs with a glow-free PATH
  PATH="$NOGLOW" "$BASH_BIN" "$PATTERNS" "$@" 2>&1
}

test_start "patterns_list_creates_the_directory_and_lists_names_without_the_extension"
assert_dir_not_exists "$PATTERN_DIR" "pattern dir absent before the first run"
_out="$(_run list)"
_rc=$?
assert_equals 0 "$_rc" "list on an empty config exits 0"
assert_dir_exists "$PATTERN_DIR" "list created the pattern directory"
assert_contains "AI Steering Patterns" "$_out" "header printed"

printf '# Architect\n\nThink in systems.\n' >"$PATTERN_DIR/architect.md"
printf '# Hardener\n' >"$PATTERN_DIR/hardener.md"
_out="$(_run list)"
assert_contains "architect" "$_out" "first pattern listed"
assert_contains "hardener" "$_out" "second pattern listed"
_refute_contains ".md" "$_out" "the .md suffix is stripped from listed names"

test_start "patterns_defaults_to_list"
_out="$(_run)"
assert_equals 0 "$?" "no argument exits 0"
assert_contains "architect" "$_out" "bare invocation lists patterns"

test_start "patterns_view_prints_the_body_with_cat_when_glow_is_missing"
_out="$(_run view architect)"
_rc=$?
assert_equals 0 "$_rc" "view exits 0"
assert_contains "Pattern: architect" "$_out" "header names the pattern"
assert_contains "Think in systems." "$_out" "body printed"

test_start "patterns_view_prefers_glow_when_available"
_glow="$DOTFILES_COV_TMPDIR/glow-bin"
mkdir -p "$_glow"
cat >"$_glow/glow" <<EOF
#!/usr/bin/env bash
printf 'glow %s\n' "\$*" >>"$LOG"
echo "rendered-by-glow"
EOF
chmod +x "$_glow/glow"
_out="$(PATH="$_glow:$NOGLOW" "$BASH_BIN" "$PATTERNS" view architect 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "view via glow exits 0"
assert_contains "rendered-by-glow" "$_out" "glow rendered the file"
assert_file_contains "$LOG" "$PATTERN_DIR/architect.md" "glow received the pattern path"

test_start "patterns_view_reports_an_unknown_pattern"
_out="$(_run view nope)"
assert_contains "Pattern not found" "$_out" "missing pattern reported"
_refute_contains "Pattern: nope" "$_out" "no pattern body is rendered"

test_start "patterns_view_without_a_name_fails_with_usage"
_out="$(_run view)"
_rc=$?
assert_equals 1 "$_rc" "view without a name exits 1"
assert_contains "Usage: dot patterns view <name>" "$_out" "usage printed"

test_start "patterns_edit_opens_the_file_in_EDITOR"
_editor="$DOTFILES_COV_TMPDIR/editor-bin"
mkdir -p "$_editor"
cat >"$_editor/fake-editor" <<EOF
#!/usr/bin/env bash
printf 'editor %s\n' "\$*" >>"$LOG"
EOF
chmod +x "$_editor/fake-editor"
: >"$LOG"
_out="$(EDITOR="$_editor/fake-editor" _run edit architect)"
_rc=$?
assert_equals 0 "$_rc" "edit exits 0"
assert_file_contains "$LOG" "editor $PATTERN_DIR/architect.md" "the editor received the pattern path"

test_start "patterns_edit_without_a_name_fails_with_usage"
_out="$(EDITOR="$_editor/fake-editor" _run edit)"
_rc=$?
assert_equals 1 "$_rc" "edit without a name exits 1"
assert_contains "Usage: dot patterns edit <name>" "$_out" "usage printed"

test_start "patterns_unknown_subcommand_prints_usage_and_fails"
_out="$(_run bogus)"
_rc=$?
assert_equals 1 "$_rc" "unknown subcommand exits 1"
assert_contains "Usage: dot patterns [list|view|edit] [name]" "$_out" "usage printed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
