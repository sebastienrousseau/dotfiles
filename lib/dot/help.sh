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

# _dot_help_overview: the domains by group, the shortcuts and the built-ins.
_dot_help_overview() {
  local rec key a b c d
  _dot_table_load
  printf 'dot · manage this machine, its shell, its agents and its configuration\n\n'
  printf 'Usage: dot <domain> [object] <verb> [args]\n'
  while IFS='|' read -r rec key a b c; do
    [[ "$rec" == grp ]] || continue
    printf '\n%s\n' "$(printf '%s' "$a" | tr '[:lower:]' '[:upper:]')"
    for d in $b; do
      _dot_record dom "$d" && printf '  %-10s %s\n' "$d" "${_REC##*|}"
    done
  done <<<"$_DOT_TABLE"
  printf '\nSHORTCUTS\n'
  while IFS='|' read -r rec key a b c; do
    [[ "$rec" == alias && "$a" == shortcut ]] && printf '  %-10s dot %s\n' "$key" "$b"
  done <<<"$_DOT_TABLE"
  printf '\nRun %s for its commands, %s for every command,\n' "'dot help <domain>'" "'dot help all'"
  printf '%s to search, %s for the catalog. Version %s.\n' "'dot help <term>'" "'dot help --json'" "${VERSION:-}"
}

# _dot_help_all: every spelling, by domain.
_dot_help_all() {
  local rec key a b c domain="" note
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    [[ "$rec" == cmd ]] || continue
    if [[ "${key%% *}" != "$domain" ]]; then
      domain="${key%% *}"
      printf '%sdot %s\n' "${note+$'\n'}" "$domain"
    fi
    note=""
    [[ -n "$a" ]] || note="  (planned)"
    printf '  dot %-28s %s%s\n' "$key" "$c" "$note"
  done <<<"$_DOT_TABLE"
}

# _dot_domain_help PREFIX: a domain's (or an object's) commands.
_dot_domain_help() {
  local rec key a b c note
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    case "$rec" in
      dom | obj) [[ "$key" == "$1" ]] && printf 'dot %s · %s\n\n' "$key" "$c" ;;
      cmd)
        [[ "$key" == "$1 "* ]] || continue
        note=""
        [[ -n "$a" ]] || note="  (planned)"
        printf '  dot %-28s %s%s\n' "$key" "$c" "$note"
        ;;
    esac
  done <<<"$_DOT_TABLE"
  return 0
}

# _dot_command_help SPELLING: one command, its effect, route and flags.
_dot_command_help() {
  local rec key a b c d legacy effect summary
  _dot_record cmd "$1" || return 1
  legacy="${_REC%%|*}" summary="${_REC##*|}" effect="${_REC#*|}" effect="${effect%%|*}"
  printf 'dot %s · %s\n\n' "$1" "$summary"
  printf '  %-10s %s\n' effect "$effect"
  if [[ -n "$legacy" ]]; then
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
