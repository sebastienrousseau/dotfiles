#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by bin/dot; inherits set -euo pipefail. ADR-020 names (N0.3).
#
# lib/dot/data/commands.txt is generated from plugins/*/dot-plugin.toml by
# tools/ci/cli_command_table.py. It maps each `dot <domain> [object] <verb>`
# spelling to the route that runs it today, and lists the shortcuts and the
# deprecated and removed names. The table is read once into a string and
# searched with pattern matching: no fork and no per-line loop (bash 3.2).
_DOT_V_UNTIL="0.2.538" # `dot -v` prints the version, with a warning, until then
_DOT_TABLE=""

_dot_table_load() {
  [[ -z "$_DOT_TABLE" ]] || return 0
  IFS= read -r -d '' _DOT_TABLE <"${_DOT_SRC:-.}/lib/dot/data/commands.txt" || true
  _DOT_TABLE=$'\n'"$_DOT_TABLE"
}

# _dot_record TYPE KEY: the fields after `TYPE|KEY|` in _REC; false if none.
# A regex, not ${var#*pat}: bash removes a pattern prefix in quadratic time.
# Keys are lowercase words and flags only, so user input never reaches the
# regex unescaped (a `|` would split the pattern into alternatives).
_dot_record() {
  _REC=""
  [[ "$2" =~ ^[a-z][a-z\ -]*$ ]] || return 1
  _dot_table_load
  local re=$'\n'"$1\\|$2\\|([^"$'\n'"]*)"
  [[ "$_DOT_TABLE" =~ $re ]] || return 1
  _REC="${BASH_REMATCH[1]}"
}

# _dot_version_ge A B: true when dotted version A is at least B.
_dot_version_ge() {
  local IFS=. i
  # shellcheck disable=SC2206 # split on dots on purpose
  local -a a=($1) b=($2)
  for i in 0 1 2; do
    ((${a[i]:-0} > ${b[i]:-0})) && return 0
    ((${a[i]:-0} < ${b[i]:-0})) && return 1
  done
  return 0
}

# _dot_lookup NAME: what NAME is at the top level. Sets _NAME_KIND to dom,
# shortcut, deprecated, removed or empty, plus _NAME_TARGET and _NAME_UNTIL.
_dot_lookup() {
  _NAME_KIND="" _NAME_TARGET="" _NAME_UNTIL=""
  if _dot_record dom "$1"; then
    _NAME_KIND=dom
  elif _dot_record alias "$1"; then
    _NAME_KIND="${_REC%%|*}"
    _REC="${_REC#*|}"
    _NAME_TARGET="${_REC%%|*}" _NAME_UNTIL="${_REC#*|}"
  fi
}

# _dot_longest TYPE WORD...: the longest run of leading WORDs that is a key of
# a TYPE record with a non-empty first field. Sets _BEST (that field) and
# _BEST_LEN (how many words; 0 when none matched).
_dot_longest() {
  local type="$1" key="" i
  shift
  _BEST="" _BEST_LEN=0
  _dot_table_load
  for ((i = 1; i <= $# && i <= 6; i++)); do
    key="${key:+$key }${!i}"
    [[ "$_DOT_TABLE" == *$'\n'"$type|$key"[\ \|]* ]] || break # no longer key
    if _dot_record "$type" "$key" && [[ -n "${_REC%%|*}" ]]; then
      _BEST="${_REC%%|*}" _BEST_LEN=$i
    fi
  done
  return 0
}

# _dot_built WORD...: the longest built spelling (cmd or run) the words start
# with, in _BEST and _BEST_LEN.
_dot_built() {
  local best="" len=0
  _dot_longest cmd "$@"
  best="$_BEST" len="$_BEST_LEN"
  _dot_longest run "$@"
  ((len > _BEST_LEN)) && _BEST="$best" _BEST_LEN="$len"
  return 0
}

# _dot_resolve WORD...: the route that runs `dot WORD...` today. Sets _RUN
# (route and leading arguments) and _RUN_USED (how many WORDs it replaces);
# _RUN stays empty when the spelling is declared but not built yet.
_dot_resolve() {
  local bare="" default=""
  _RUN="" _RUN_USED=0
  if _dot_record dom "$1"; then
    default="${_REC%%|*}" bare="${_REC#*|}" bare="${bare%%|*}"
  fi
  _dot_built "$@"
  if ((_BEST_LEN > 0)); then
    _RUN="$_BEST" _RUN_USED="$_BEST_LEN"
  elif [[ -z "${2:-}" || "${2:-}" == -* ]]; then
    _dot_resolve_bare "$1" "$bare" "$default"
  elif _dot_record obj "$1 $2"; then
    _dot_resolve_object "$@"
  elif [[ -n "$bare" && "$_DOT_TABLE" != *$'\n'"cmd|$1 $2"[\ \|]* ]]; then
    _RUN="$bare" _RUN_USED=1 # an old subcommand of the domain's own route
  fi
  return 0
}

# _dot_resolve_bare DOMAIN ROUTE DEFAULT: the domain word alone runs its own
# route, else its default verb (N5).
_dot_resolve_bare() {
  if [[ -n "$2" ]]; then
    _RUN="$2" _RUN_USED=1
  else
    _dot_built "$1" "$3"
    ((_BEST_LEN == 0)) || _RUN="$_BEST" _RUN_USED=1
  fi
}

# _dot_resolve_object DOMAIN OBJECT [WORD...]: an object with no verb runs
# its default verb; _REC holds the object's record.
_dot_resolve_object() {
  if [[ -z "${3:-}" || "${3:-}" == -* ]]; then
    _dot_built "$1" "$2" "${_REC%%|*}"
    ((_BEST_LEN == 0)) || _RUN="$_BEST" _RUN_USED=2
  fi
}

# _dot_warn_deprecated NAME NEW ARGS: tell the user once per shell session.
# Help (-h, --help) warns without recording it: help writes nothing.
_dot_warn_deprecated() {
  local dir="${XDG_STATE_HOME}/dot/cli/deprecated" seen=""
  local mark="$dir/${PPID:-0}"
  [[ -f "$mark" ]] && seen="$(<"$mark")"
  case $'\n'"$seen"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  printf "dot: 'dot %s' is deprecated; use 'dot %s' (it stops working in %s)\n" \
    "$1" "$2" "$_NAME_UNTIL" >&2
  case " $3 " in *" --help "* | *" -h "*) return 0 ;; esac
  # One marker per shell; markers of shells gone since yesterday are pruned.
  find "$dir" -type f -mtime +0 -delete 2>/dev/null || true
  mkdir -p "$dir" 2>/dev/null && printf '%s\n' "$1" >>"$mark" 2>/dev/null
  return 0
}

# _dot_domain_help DOMAIN: the domain's commands, from its manifest.
_dot_domain_help() {
  local rec key a b c note
  _dot_table_load
  while IFS='|' read -r rec key a b c; do
    case "$rec" in
      dom) [[ "$key" == "$1" ]] && printf 'dot %s · %s\n\n' "$key" "$c" ;;
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

# _dot_gnu_flags WORD...: GNU flags (N9). -V is the version and -v is
# --verbose; `dot -v` alone still prints the version, with a warning, for
# one release. Sets _ARGV.
_dot_gnu_flags() {
  _ARGV=("$@")
  case "${1:-}" in
    -V) _ARGV=(version "${@:2}") ;;
    -v)
      if [[ $# -eq 1 ]] && ! _dot_version_ge "$VERSION" "$_DOT_V_UNTIL"; then
        printf "dot: '-v' means --verbose from %s; use 'dot -V' for the version\n" "$_DOT_V_UNTIL" >&2
        _ARGV=(version)
        return 0
      fi
      export DOT_VERBOSE=1
      _ARGV=("" "${@:2}")
      [[ $# -eq 1 ]] || _ARGV=("${@:2}")
      ;;
  esac
  return 0
}

# _dot_old_name WORD...: a deprecated name runs and warns until its release,
# then exits 127 like a removed one; a shortcut becomes its target. Sets
# _ARGV, and _NAME_KIND to dom when the words now start with a domain.
_dot_old_name() {
  _ARGV=("$@")
  _dot_lookup "$1"
  case "$_NAME_KIND" in
    deprecated | removed)
      if [[ "$_NAME_KIND" == removed ]] || _dot_version_ge "$VERSION" "$_NAME_UNTIL"; then
        printf "dot: 'dot %s' was removed; use 'dot %s'\n" "$1" "$_NAME_TARGET" >&2
        exit 127
      fi
      _dot_longest leg "$@" # the spelling of this exact invocation, if any
      _dot_warn_deprecated "$1" "${_BEST:-$_NAME_TARGET}" "$*"
      ;;
    shortcut)
      # shellcheck disable=SC2206 # the target is words
      _ARGV=($_NAME_TARGET "${@:2}")
      _NAME_KIND=dom
      ;;
  esac
  return 0
}

# _dot_planned DOMAIN WORD...: true when the words name a declared command
# with no route yet.
_dot_planned() {
  [[ "$_NAME_KIND" == dom && -n "${2:-}" ]] || return 1
  _dot_record cmd "$1 $2 ${3:-}" || _dot_record cmd "$1 $2"
}

# _dot_spelled WORD...: `dot <domain> ...` and `dot help <term>` become the
# route that runs them today. Sets _ARGV.
_dot_spelled() {
  _ARGV=("$@")
  [[ "$_NAME_KIND" == dom || ("$1" == help && $# -gt 1) ]] || return 0
  _dot_resolve "$@"
  if [[ -n "$_RUN" ]]; then
    # shellcheck disable=SC2206 # a route and its leading arguments
    _ARGV=($_RUN "${@:$((_RUN_USED + 1))}")
  elif _dot_planned "$@"; then
    _dot_unknown "$@" # never let the domain's own route take a planned verb
  elif [[ "$1" == help ]] && _dot_lookup "$2" && [[ "$_NAME_KIND" == dom ]] &&
    [[ -z "$(_dot_help_summary "$2")" ]]; then
    _dot_domain_help "$2"
    exit 0
  fi
  return 0
}

# _dot_names WORD...: the command line bin/dot should route; no command
# at all shows the overview. Sets _ARGV.
_dot_names() {
  _NAME_KIND=""
  _dot_gnu_flags "$@"
  set -- "${_ARGV[@]}"
  if [[ -z "$1" ]]; then
    show_help
    exit 0
  fi
  _dot_old_name "$@"
  set -- "${_ARGV[@]}"
  _dot_spelled "$@"
}

# _dot_unknown WORD...: nothing routed WORD. A domain lists its commands
# when it was given no verb; anything else exits 127 (N10).
_dot_unknown() {
  local words="${2:-}"
  if [[ "$_NAME_KIND" == dom && (-z "$words" || "$words" == -*) ]]; then
    _dot_domain_help "$1"
    exit 0
  fi
  if [[ "$_NAME_KIND" == dom ]]; then
    [[ "${3:-}" =~ ^[a-z]+$ ]] && words="$words $3"
    echo "dot: 'dot $1 $words' is not available yet; run 'dot help $1'" >&2
    exit 127
  fi
  echo "Unknown command: ${1:-}" >&2
  echo "Run 'dot help' for available commands." >&2
  exit 127
}
