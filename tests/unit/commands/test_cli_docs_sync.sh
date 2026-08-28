#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Docs/code alignment ratchet for the whole dot CLI. Uses the
# shared runtime module at tests/framework/docs_sync_helpers.sh so
# the same logic drives tests/unit/theme/test_theme_docs_sync.sh.
#
# When someone documents a partially-covered command in all remaining
# loci, it auto-joins the ratchet on the next run — no manual edit
# required. When a currently-ratcheted command loses coverage in any
# locus, the run fails.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"
source "$SCRIPT_DIR/../../framework/docs_sync_helpers.sh"

BASH_COMP="$REPO_ROOT/share/completions/bash/dot"
ZSH_COMP="$REPO_ROOT/share/completions/zsh/_dot"
FISH_TMPL="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl"
MANPAGE="$REPO_ROOT/share/man/man1/dot.1"
HELP_DIR="$REPO_ROOT/scripts/dot/commands"

# ---------------------------------------------------------------------------
# Enumerate the full command surface at runtime.
# ---------------------------------------------------------------------------
mapfile -t ALL_COMMANDS < <(_docs_extract_top_level_commands "$REPO_ROOT")

# ---------------------------------------------------------------------------
# Partition into fully-documented / partial / bare buckets.
# ---------------------------------------------------------------------------
_docs_partition_by_coverage \
  "$BASH_COMP" "$ZSH_COMP" "$FISH_TMPL" "$MANPAGE" \
  "${ALL_COMMANDS[@]}"
_docs_print_partition_summary

# COMMANDS is the ratchet — auto-computed as the fully-documented set.
COMMANDS=("${DOCS_FULL[@]}")

# ---------------------------------------------------------------------------
# Now enforce: every command in COMMANDS still resolves in every locus.
# (Redundant with DOCS_FULL classification but keeps the failure
# message aligned with what CI is expected to print.)
# ---------------------------------------------------------------------------
missing_bash=(); missing_zsh=(); missing_fish=(); missing_man=(); missing_help=()

_in_help_source() {
  local cmd="$1"
  # `dot help` output is assembled from files in scripts/dot/commands
  # (or module files). A command is bound if any of:
  #   * cmd_<name>() function defined in a module
  #   * `  <name>)` dispatch case (bare or alternation) in any module
  #   * A module file at scripts/dot/commands/<name>.sh
  #   * A bin/dot-<name> executable
  #   * `<name>|<namespace>` entry in bin/dot's routes heredoc
  # Alternation-aware match: `foo | bar | ${cmd} | baz)` and
  # `${cmd} | foo)` and bare `${cmd})` all count.
  local alt_re="^  ([a-zA-Z0-9_-]+[[:space:]]*\\|[[:space:]]*)*${cmd}([[:space:]]*\\|[[:space:]]*[a-zA-Z0-9_-]+)*\\)"
  grep -rqE "^cmd_${cmd//-/_}\\(\\)" "$HELP_DIR" 2>/dev/null \
    || grep -rqE "$alt_re" "$HELP_DIR" 2>/dev/null \
    || [[ -f "$HELP_DIR/${cmd}.sh" ]] \
    || [[ -x "$REPO_ROOT/bin/dot-${cmd}" ]] \
    || grep -qE "$alt_re" "$REPO_ROOT/bin/dot" \
    || grep -qE "^${cmd}\\|[a-z]+$" "$REPO_ROOT/bin/dot"
}

for cmd in "${COMMANDS[@]}"; do
  _docs_in_bash_comp "$BASH_COMP" "$cmd" || missing_bash+=("$cmd")
  _docs_in_zsh_comp  "$ZSH_COMP"  "$cmd" || missing_zsh+=("$cmd")
  _docs_in_fish_tmpl "$FISH_TMPL" "$cmd" || missing_fish+=("$cmd")
  _docs_in_manpage   "$MANPAGE"   "$cmd" || missing_man+=("$cmd")
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
# Every ratcheted command has at least one code binding.
# ---------------------------------------------------------------------------
test_start "cli_every_command_has_at_least_one_binding"
orphans=()
for cmd in "${COMMANDS[@]}"; do
  _in_help_source "$cmd" || orphans+=("$cmd")
done
if [[ ${#orphans[@]} -eq 0 ]]; then _ok; else _fail "orphans: ${orphans[*]}"; fi

# ---------------------------------------------------------------------------
# 100% ratchet gate. As of 2026-08-28 every top-level command is
# documented in all 4 loci (bash + zsh + fish + man). This assertion
# fails the moment a new command lands without matching doc updates —
# preventing silent regressions of the ratchet. Growing budget: any
# newly-added command must join Full immediately, no Partial period.
# ---------------------------------------------------------------------------
test_start "cli_no_partial_or_bare_commands_ratchet_full"
if [[ ${#DOCS_PARTIAL[@]} -eq 0 && ${#DOCS_BARE[@]} -eq 0 ]]; then
  _ok
else
  _fail "partial=${DOCS_PARTIAL[*]:-none} bare=${DOCS_BARE[*]:-none}"
fi

_cmd_finish
