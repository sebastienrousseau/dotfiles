#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Shared runtime helpers for docs-sync ratchets.
#
# Two consumers use the same shape:
#   * tests/unit/commands/test_cli_docs_sync.sh — pan-CLI top-level
#     commands from bin/dot's route case + scripts/dot/commands/*.sh
#     module dispatch cases + bin/dot-* executables.
#   * tests/unit/theme/test_theme_docs_sync.sh — theme subcommands
#     from scripts/theme/switch.sh's case dispatch.
#
# Both need to check the same 4 loci (bash + zsh + fish + man) plus
# an optional 5th (helper source or docs-guide table row).
#
# This file exposes:
#   _docs_extract_from_case_block <file>       — awk the case labels
#                                                out of a bash script
#   _docs_in_bash_comp <comp> <cmd>            — grep test for bash
#   _docs_in_zsh_comp  <comp> <cmd>            — grep test for zsh
#   _docs_in_fish_tmpl <comp> <cmd>            — grep test for fish
#   _docs_in_manpage   <man>  <cmd>            — grep test for man
#   _docs_partition_by_coverage \
#       <bash> <zsh> <fish> <man> [cmds ...]   — split into 3 buckets:
#                                                fully-covered, partial,
#                                                bare — printed as
#                                                three arrays via
#                                                shared globals.
#
# shellcheck shell=bash

[[ "${_DOT_DOCS_SYNC_HELPERS_LOADED:-0}" == "1" ]] && return 0
_DOT_DOCS_SYNC_HELPERS_LOADED=1

# ---------------------------------------------------------------------------
# _docs_extract_from_case_block — awk the top-level `case ... in`
# block of a bash script and print each dispatch label on its own line.
# Handles alternation with optional whitespace: `foo | bar | baz)`.
# Skips *) wildcard and "" empty defaults.
# ---------------------------------------------------------------------------
_docs_extract_from_case_block() {
  local file="$1"
  awk '
    /^case "\$\{1:-\}" in/ || /^case "\$route" in/ { in_case=1; next }
    /^esac[[:space:]]*$/ && in_case { in_case=0 }
    in_case && /^  [a-z][a-zA-Z0-9_-]*([[:space:]]*\|[[:space:]]*[a-zA-Z0-9_-]+)*[[:space:]]*\)/ {
      # Capture the label(s) between the leading 2 spaces and the `)`.
      match($0, /^  ([^)]+)\)/, m)
      n = split(m[1], parts, /[[:space:]]*\|[[:space:]]*/)
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
        if (parts[i] != "" && parts[i] != "*" && parts[i] !~ /^-/) {
          print parts[i]
        }
      }
    }
  ' "$file"
}

# ---------------------------------------------------------------------------
# 4 locus checks — bash / zsh / fish / man. Each returns 0 if the
# command is documented in that locus, non-zero otherwise.
# ---------------------------------------------------------------------------
_docs_in_bash_comp() {
  local file="$1" cmd="$2"
  grep -qE "\\b${cmd}\\b" "$file" 2>/dev/null
}

_docs_in_zsh_comp() {
  local file="$1" cmd="$2"
  # zsh entries follow `'cmd:Description'` inside a _describe array.
  grep -qE "'${cmd}:" "$file" 2>/dev/null
}

_docs_in_fish_tmpl() {
  local file="$1" cmd="$2"
  # fish uses `-a <cmd>` for `complete -a` completions.
  grep -qE "\\-a ${cmd}\\b|__fish_seen_subcommand_from ${cmd}" "$file" 2>/dev/null
}

_docs_in_manpage() {
  local file="$1" cmd="$2"
  # dot(1) / dot-theme(1) man pages use `.B <cmd>` after a `.TP` tag.
  # groff escapes literal hyphens as `\-`, so `alias-check` in source
  # renders as `alias\-check` in the .1 file. Also handle the comma-
  # separated bundle form (`.B cl, copilot, gemini`). Matching a
  # literal backslash in ERE requires four source-level backslashes:
  # bash halves to two, ERE halves again to the one literal `\`.
  local escaped="${cmd//-/\\\\-}"
  grep -qE "^\.B ((${cmd}|${escaped})|.*[[:space:],]+(${cmd}|${escaped}))([[:space:],]|$)" \
    "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# _docs_partition_by_coverage — split a command list into:
#   DOCS_FULL    — documented in all 4 loci; forms the ratchet
#   DOCS_PARTIAL — documented in 1-3 loci; tracked, not fatal
#   DOCS_BARE    — no docs yet; tracked, not fatal
# Callers pass the 4 locus file paths, then the command list.
# Sets the three arrays as globals for the caller to inspect.
#
# Usage:
#   _docs_partition_by_coverage BASH_COMP ZSH_COMP FISH_TMPL MANPAGE cmd1 cmd2 ...
# ---------------------------------------------------------------------------
_docs_partition_by_coverage() {
  local bash_comp="$1" zsh_comp="$2" fish_tmpl="$3" manpage="$4"
  shift 4
  DOCS_FULL=()
  DOCS_PARTIAL=()
  DOCS_BARE=()
  local cmd b z f m score
  for cmd in "$@"; do
    b=0; z=0; f=0; m=0
    _docs_in_bash_comp "$bash_comp" "$cmd" && b=1
    _docs_in_zsh_comp  "$zsh_comp"  "$cmd" && z=1
    _docs_in_fish_tmpl "$fish_tmpl" "$cmd" && f=1
    _docs_in_manpage   "$manpage"   "$cmd" && m=1
    score=$((b + z + f + m))
    if (( score == 4 )); then
      DOCS_FULL+=("$cmd")
    elif (( score == 0 )); then
      DOCS_BARE+=("$cmd")
    else
      DOCS_PARTIAL+=("$cmd")
    fi
  done
}

# ---------------------------------------------------------------------------
# _docs_print_partition_summary — pretty-print the three buckets so
# users running the test can see the punch list at a glance.
# ---------------------------------------------------------------------------
_docs_print_partition_summary() {
  printf '  \033[1;36mRatchet\033[0m: %d fully-documented commands locked in.\n' \
    "${#DOCS_FULL[@]}"
  if (( ${#DOCS_PARTIAL[@]} > 0 )); then
    printf '  \033[0;33mPartial\033[0m (documented in 1-3 loci): %s\n' \
      "${DOCS_PARTIAL[*]}"
  fi
  if (( ${#DOCS_BARE[@]} > 0 )); then
    printf '  \033[0;36mBare\033[0m (no docs yet): %s\n' "${DOCS_BARE[*]}"
  fi
  echo ""
}
