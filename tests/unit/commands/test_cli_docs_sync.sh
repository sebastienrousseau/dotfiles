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

# Canonical high-signal command list. This is the RATCHET — every
# command here must be documented in bash, zsh, fish completions AND
# the man page AND have at least one code binding. When a new
# command graduates from experimental to daily-use, add it here to
# lock in its coverage.
#
# Growing budget: extend this list over time as more of the surface
# gets synchronised documentation. Removing entries is a regression.
COMMANDS=(
  apply
  attest
  bundle
  cd
  diff
  doctor
  edit
  env
  health
  mcp
  profile
  remove
  secrets
  snapshot
  status
  sync
  theme
  update
  wallpaper
)

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
  # (or module files). Look for `cmd_<cmd>()` or dispatch case.
  grep -rqE "^cmd_${cmd//-/_}\\(\\)|^  ${cmd}\\)" "$HELP_DIR" 2>/dev/null \
    || [[ -x "$REPO_ROOT/bin/dot-${cmd}" ]]
}

# ---------------------------------------------------------------------------
# Sweep every command through every locus.
# ---------------------------------------------------------------------------
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
