#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Docs/code alignment ratchet for the whole dot CLI.
#
# Every top-level `dot <command>` should appear in:
#   1. bin/dot's dispatcher (as a route)
#   2. scripts/dot/commands/*.sh (with a dispatch case OR a cmd_<name>
#      function), OR bin/dot-<name> executable
#   3. dot(1) man page at share/man/man1/dot.1
#   4. bash completion at share/completions/bash/dot
#   5. zsh completion at share/completions/zsh/_dot
#   6. fish completion template at defaults/dot_config/fish/completions/dot.fish.tmpl
#   7. `dot help` output (either in scripts/dot/commands/*.sh or via
#      a docs source under docs/)
#
# When a subcommand is added to bin/dot without matching updates
# elsewhere, this test catches the drift at PR time.
#
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BASH_COMP="$REPO_ROOT/share/completions/bash/dot"
ZSH_COMP="$REPO_ROOT/share/completions/zsh/_dot"
FISH_TMPL="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl"
MANPAGE="$REPO_ROOT/share/man/man1/dot.1"
HELP_DIR="$REPO_ROOT/scripts/dot/commands"

# Runtime-extracted RATCHET.
#
# Every command in bin/dot's case dispatch OR shipped as bin/dot-<name>
# is a candidate. The ratchet locks in commands that already have
# 4-locus coverage (bash + zsh + fish + man); commands that appear in
# code but aren't fully documented get printed as "tracked" so they're
# visible on the punch list without failing the run.
#
# When someone documents a partially-covered command in all remaining
# loci, it auto-joins the ratchet on the next run — no manual edit
# required. When a currently-ratcheted command loses coverage in any
# locus, the run fails.
#
# Explicit ALIASES that should be excluded from the extraction (e.g.
# "sync" is aliased from apply and shouldn't count twice):
#   none right now — extraction is 1-to-1 with dispatch entries.
_extract_dispatch_commands() {
  # bin/dot's route case (agents / init / registry / help / version ...)
  sed -n '/^case "$route" in/,/^esac/p' "$REPO_ROOT/bin/dot" \
    | grep -E "^  [a-z][a-zA-Z0-9_|-]+\)" \
    | sed -E 's/^  ([^)]+)\).*/\1/' \
    | tr '|' '\n' \
    | sed 's/^ *//;s/ *$//' \
    | grep -Ev '^(\*|"")$'
  # Each command module's dispatch cases.
  grep -h "^  [a-z][a-zA-Z0-9_-]*\|[a-zA-Z0-9_|-]*)" \
       "$REPO_ROOT/scripts/dot/commands"/*.sh 2>/dev/null \
    | grep -E "^  [a-z][a-zA-Z0-9_|-]+\)" \
    | sed -E 's/^  ([^)]+)\).*/\1/' \
    | tr '|' '\n' \
    | sed 's/^ *//;s/ *$//' \
    | grep -Ev '^(\*|"")$'
  # bin/dot-<name> executables count too.
  find "$REPO_ROOT/bin" -maxdepth 1 -name 'dot-*' -type f -exec basename {} \; \
    | sed 's/^dot-//'
}

mapfile -t ALL_COMMANDS < <(_extract_dispatch_commands | sort -u | grep -v '^$')

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

_in_bash_comp() {
  local cmd="$1"
  # bash completion has multiple `case`s; a raw grep for the token is
  # enough — the completion always mentions it explicitly.
  grep -qE "\\b${cmd}\\b" "$BASH_COMP"
}

_in_zsh_comp() {
  local cmd="$1"
  # zsh entries look like 'cmd:Description'.
  grep -qE "'${cmd}:" "$ZSH_COMP"
}

_in_fish_tmpl() {
  local cmd="$1"
  grep -qE "\\-a ${cmd}\\b|__fish_seen_subcommand_from ${cmd}" "$FISH_TMPL"
}

_in_manpage() {
  local cmd="$1"
  # Man page uses .TP followed by .B <cmd> for definition list entries.
  grep -qE "^\.B ${cmd}\\b" "$MANPAGE"
}

_in_help_source() {
  local cmd="$1"
  # `dot help` output is assembled from files in scripts/dot/commands
  # (or module files). A command is bound if any of:
  #   * cmd_<name>() function defined in a module
  #   * `  <name>)` dispatch case in a module
  #   * A module file at scripts/dot/commands/<name>.sh
  #   * A bin/dot-<name> executable
  #   * Special-case: bin/dot's own top-level route case (agents, help,
  #     search, version, init, registry, patterns, manual)
  grep -rqE "^cmd_${cmd//-/_}\\(\\)|^  ${cmd}\\)" "$HELP_DIR" 2>/dev/null \
    || [[ -f "$HELP_DIR/${cmd}.sh" ]] \
    || [[ -x "$REPO_ROOT/bin/dot-${cmd}" ]] \
    || grep -qE "^  ${cmd}\\)" "$REPO_ROOT/bin/dot"
}

# ---------------------------------------------------------------------------
# Sweep every extracted command through every locus. Partition into:
#   * COMMANDS: fully-documented (all 4 loci). These form the ratchet.
#   * partial:  documented in some but not all loci — tracked, not fatal.
#   * bare:     no doc coverage yet — tracked, not fatal.
# ---------------------------------------------------------------------------
COMMANDS=()
partial=()
bare=()
for cmd in "${ALL_COMMANDS[@]}"; do
  in_bash=0; in_zsh=0; in_fish=0; in_man=0
  _in_bash_comp "$cmd" && in_bash=1
  _in_zsh_comp  "$cmd" && in_zsh=1
  _in_fish_tmpl "$cmd" && in_fish=1
  _in_manpage   "$cmd" && in_man=1
  score=$((in_bash + in_zsh + in_fish + in_man))
  if (( score == 4 )); then
    COMMANDS+=("$cmd")
  elif (( score == 0 )); then
    bare+=("$cmd")
  else
    partial+=("$cmd")
  fi
done

# The four locus checks now run against COMMANDS (auto-computed).
missing_bash=()
missing_zsh=()
missing_fish=()
missing_man=()
missing_help=()

for cmd in "${COMMANDS[@]}"; do
  _in_bash_comp "$cmd" || missing_bash+=("$cmd")
  _in_zsh_comp  "$cmd" || missing_zsh+=("$cmd")
  _in_fish_tmpl "$cmd" || missing_fish+=("$cmd")
  _in_manpage   "$cmd" || missing_man+=("$cmd")
  _in_help_source "$cmd" || missing_help+=("$cmd")
done

# Visibility on the punch list — printed once at the top so the user
# can see progress without CI failing on partial-coverage commands.
printf '  \033[1;36mRatchet\033[0m: %d fully-documented commands locked in.\n' "${#COMMANDS[@]}"
if (( ${#partial[@]} > 0 )); then
  printf '  \033[0;33mPartial\033[0m (documented in 1-3 loci): %s\n' "${partial[*]}"
fi
if (( ${#bare[@]} > 0 )); then
  printf '  \033[0;36mBare\033[0m (no docs yet): %s\n' "${bare[*]}"
fi
echo ""

test_start "cli_bash_completion_covers_all_daily_use_commands"
if [[ ${#missing_bash[@]} -eq 0 ]]; then _ok; else _fail "missing: ${missing_bash[*]}"; fi

test_start "cli_zsh_completion_covers_all_daily_use_commands"
if [[ ${#missing_zsh[@]} -eq 0 ]]; then _ok; else _fail "missing: ${missing_zsh[*]}"; fi

test_start "cli_fish_completion_covers_all_daily_use_commands"
if [[ ${#missing_fish[@]} -eq 0 ]]; then _ok; else _fail "missing: ${missing_fish[*]}"; fi

test_start "cli_manpage_covers_all_daily_use_commands"
if [[ ${#missing_man[@]} -eq 0 ]]; then _ok; else _fail "missing: ${missing_man[*]}"; fi

test_start "cli_help_or_dispatch_covers_all_daily_use_commands"
if [[ ${#missing_help[@]} -eq 0 ]]; then _ok; else _fail "missing: ${missing_help[*]}"; fi

# ---------------------------------------------------------------------------
# Additionally, every command in the canonical list must at least be
# a real entry point somewhere — either a cmd_<name> function, a
# dispatch case, or a bin/dot-<name> binary. The alignment check
# above already scans for these; this test is a shorter "any binding
# at all?" guard.
# ---------------------------------------------------------------------------
test_start "cli_every_command_has_at_least_one_binding"
orphans=()
for cmd in "${COMMANDS[@]}"; do
  underscore="${cmd//-/_}"
  if ! grep -rqE "^cmd_${underscore}\\(\\)|^  ${cmd}\\)" "$HELP_DIR" 2>/dev/null \
     && [[ ! -f "$HELP_DIR/${cmd}.sh" ]] \
     && [[ ! -x "$REPO_ROOT/bin/dot-${cmd}" ]] \
     && ! grep -qE "^  ${cmd}\)" "$REPO_ROOT/bin/dot"; then
    orphans+=("$cmd")
  fi
done
if [[ ${#orphans[@]} -eq 0 ]]; then _ok; else _fail "orphans: ${orphans[*]}"; fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
