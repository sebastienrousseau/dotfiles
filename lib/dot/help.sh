#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by bin/dot after lib/dot/names.sh; inherits set -euo pipefail.
#
# `dot help` from the command table (ADR-020, N0.4): the overview groups
# the domains as schemas/cli/domains.json does, `dot help all` lists every
# spelling, and `dot help <spelling>` (or `dot <spelling> --help`) shows one
# domain, object or command with its flags. All of it comes from
# lib/dot/data/commands.txt, so help cannot drift from the manifests.
# `dot help --json` prints lib/dot/data/commands.json, the same names as one
# catalog for agents and tools.

# _dot_upper TEXT: TEXT in capitals, in _UP, without a fork (bash 3.2 has
# no ${var^^}; a `tr` per group heading cost a fork each, P13).
_dot_upper() {
  local lower=abcdefghijklmnopqrstuvwxyz upper=ABCDEFGHIJKLMNOPQRSTUVWXYZ c i head
  _UP=""
  for ((i = 0; i < ${#1}; i++)); do
    c="${1:i:1}"
    head="${lower%%"$c"*}"
    [[ "$head" == "$lower" ]] || c="${upper:${#head}:1}"
    _UP+="$c"
  done
}

# _dot_help_overview: the domains by group, the shortcuts and the built-ins.
# One pass over the table collects the groups, domain summaries and
# shortcuts (P13: a lookup per domain rescanned the whole table).
_dot_help_overview() {
  local rec key a b c d v groups="" shortcuts=""
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    case "$rec" in
      grp) groups+="$a|$b"$'\n' ;;
      dom) printf -v "_dot_dom_$key" '%s' "$c" ;;
      alias)
        [[ "$a" == shortcut ]] || continue
        printf -v v '  %-10s dot %s\n' "$key" "$b"
        shortcuts+="$v"
        ;;
    esac
  done <<<"$_DOT_TABLE"
  printf 'dot · manage this machine, its shell, its agents and its configuration\n\n'
  printf 'Usage: dot <domain> [object] <verb> [args]\n'
  while IFS='|' read -r a b; do
    [[ -n "$a" ]] || continue
    _dot_upper "$a"
    printf '\n%s\n' "$_UP"
    for d in $b; do
      v="_dot_dom_$d"
      [[ -z "${!v:-}" ]] || printf '  %-10s %s\n' "$d" "${!v}"
    done
  done <<<"$groups"
  printf '\nSHORTCUTS\n%s' "$shortcuts"
  printf '\nRun %s for its commands, %s for every command,\n' "'dot help <domain>'" "'dot help all'"
  printf '%s to search, %s for the catalog. Version %s.\n' "'dot help <term>'" "'dot help --json'" "${VERSION:-}"
}

# _dot_help_planned_line KEY ROUTE SUMMARY: one command's help line; a
# planned one (no route yet) only under `dot help --all`
# (_DOT_HELP_PLANNED=1, D12), else counted in _DOT_HIDDEN.
_dot_help_planned_line() {
  if [[ -n "$2" ]]; then
    printf '  dot %-28s %s\n' "$1" "$3"
  elif [[ "${_DOT_HELP_PLANNED:-0}" == 1 ]]; then
    printf '  dot %-28s %s  (planned)\n' "$1" "$3"
  else
    _DOT_HIDDEN=$((_DOT_HIDDEN + 1))
  fi
}

# _dot_help_hidden_note: say how many planned commands were left out.
_dot_help_hidden_note() {
  ((_DOT_HIDDEN == 0)) || printf "\n  %d planned, not built yet: 'dot help --all' lists them\n" "$_DOT_HIDDEN"
}

# _dot_help_all: every built spelling, by domain; `dot help --all` sets
# _DOT_HELP_PLANNED=1 to add the planned ones.
_dot_help_all() {
  local rec key a b c domain=""
  _DOT_HIDDEN=0
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    [[ "$rec" == cmd ]] || continue
    if [[ "${key%% *}" != "$domain" ]]; then
      printf '%sdot %s\n' "${domain:+$'\n'}" "${key%% *}"
      domain="${key%% *}"
    fi
    _dot_help_planned_line "$key" "$a" "$c"
  done <<<"$_DOT_TABLE"
  _dot_help_hidden_note
}

# _dot_domain_help PREFIX: a domain's (or an object's) commands.
_dot_domain_help() {
  local rec key a b c
  _DOT_HIDDEN=0
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    case "$rec" in
      dom | obj) [[ "$key" == "$1" ]] && printf 'dot %s · %s\n\n' "$key" "$c" ;;
      cmd) [[ "$key" != "$1 "* ]] || _dot_help_planned_line "$key" "$a" "$c" ;;
    esac
  done <<<"$_DOT_TABLE"
  _dot_help_hidden_note
  return 0
}

# _dot_command_help SPELLING: one command, its effect, route and flags.
_dot_command_help() {
  local rec key a b c d legacy effect summary
  _dot_record cmd "$1" || return 1
  legacy="${_REC%%|*}" summary="${_REC##*|}" effect="${_REC#*|}" effect="${effect%%|*}"
  printf 'dot %s · %s\n\n' "$1" "$summary"
  printf '  %-10s %s\n' effect "$effect"
  if [[ "$legacy" == @* ]]; then
    legacy="${legacy#@}"
    printf "  %-10s dot-%s %s, the plugin's entry\n" runs "${legacy%% *}" "${legacy#* }"
  elif [[ -n "$legacy" ]]; then
    printf '  %-10s dot %s, until the domain is extracted\n' runs "$legacy"
  else
    printf '  %-10s planned, not built yet\n' state
  fi
  while IFS='|' read -r rec key a b c d; do
    [[ "$rec" == flag && "$key" == "$1" ]] || continue
    printf '  --%-16s %s\n' "$a${b:+, -$b}${c:+ <$c>}" "$d"
  done <<<"$_DOT_TABLE"
}

# _dot_help_spelling WORD...: help for the longest leading run of WORDs that
# is a domain, object or command (a shortcut first becomes its target);
# false when none is.
_dot_help_spelling() {
  local n key
  if _dot_record alias "${1:-}" && [[ "${_REC%%|*}" == shortcut ]]; then
    key="${_REC#*|}"
    printf 'dot %s is short for dot %s\n\n' "$1" "${key%%|*}"
    # shellcheck disable=SC2086 # the target is words
    set -- ${key%%|*} "${@:2}"
  fi
  for ((n = $#; n >= 1; n--)); do
    key="${*:1:n}"
    if _dot_command_help "$key"; then
      return 0
    elif _dot_record obj "$key" || _dot_record dom "$key"; then
      _dot_domain_help "$key"
      return 0
    fi
  done
  return 1
}

# _dot_help_search TERM: commands whose spelling or summary contains TERM,
# and old names that do, with their new spelling (they still run until
# their release); false when nothing matches.
_dot_help_search() {
  local rec key a b c found=1 restore
  restore="$(shopt -p nocasematch)"
  shopt -s nocasematch
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    if [[ "$rec" == cmd && "$key $c" == *"$1"* ]]; then
      printf '  dot %-28s %s\n' "$key" "$c"
    elif [[ "$rec" == alias && "$key" == *"$1"* && "$a" == shortcut ]]; then
      printf '  dot %-28s short for dot %s\n' "$key" "$b"
    elif [[ "$rec" == alias && "$key" == *"$1"* ]]; then
      printf '  dot %-28s now dot %s%s\n' "$key" "$b" "${c:+, until $c}"
    else
      continue
    fi
    found=0
  done <<<"$_DOT_TABLE"
  eval "$restore"
  return "$found"
}
