#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Every shared helper a script calls must be reachable from that script.
#
# `check_cmd`, `sed_in_place` and `has_command` were each copy-pasted into
# half a dozen scripts. Consolidating them into lib/dot/utils.sh is only
# safe if the callers actually source it, and that is exactly the step
# that is easy to skip: deleting a local definition and leaving behind a
# comment saying "provided by lib/dot/utils.sh" looks complete in a diff
# and still yields `check_cmd: command not found` at runtime.
#
# That mistake was made once, on the theme reconciliation branch: five of
# the six scripts lost their local copy and not one gained a source line.
# `scripts/diagnostics/doctor.sh` emitted the error twelve times.
#
# The linter cannot see it either — SC1091 is about unresolvable source
# paths, not undefined functions — and CI never invokes these diagnostics
# scripts, so nothing else would catch it. Hence a static check here:
# for every file that calls a shared helper, the helper must be defined in
# that file's `source` closure, or in the closure of a script that sources
# it (which is how partials such as scripts/ops/heal-tools.sh qualify).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

cd "$REPO_ROOT" || exit 1

# Helpers that live in lib/ and are shared rather than script-local. A name
# only belongs here once it has a single canonical definition; listing one
# that is still duplicated does not fail, it just checks less.
SHARED_HELPERS="check_cmd sed_in_place has_command"

# Where callers are looked for. lib/ is included as a caller source but
# never treated as an entry point.
SCAN_DIRS="bin scripts install tools lib"

# Bash 3.2: no associative arrays. Memo tables are newline-delimited
# "key<TAB>value" strings searched with a fixed-string grep.

# Collapse `a/b/../c` and `./` without realpath, which stock macOS lacks.
_norm() {
  local p="$1" out="" seg
  local IFS=/
  for seg in $p; do
    case "$seg" in
      '' | .) continue ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  printf '%s\n' "${out#/}"
}

# `source X` / `. X` targets of $1, as repo-relative paths. Handles the two
# idioms in this repo: a literal relative path, and a "$SOME_DIR/..."
# prefix where SOME_DIR is the sourcing file's own directory. Targets that
# do not resolve to a real file are dropped — an unresolvable path cannot
# be proven missing from here.
_sources_of() {
  local file="$1" dir arg p
  dir="$(dirname "$file")"
  grep -hE '^[[:space:]]*(source|\.)[[:space:]]+' "$file" 2>/dev/null |
    sed -E 's/^[[:space:]]*(source|\.)[[:space:]]+//; s/[[:space:]]*(#.*)?$//' |
    while IFS= read -r arg; do
      arg="${arg%\"}"
      arg="${arg#\"}"
      case "$arg" in
        *'$'*) p="$dir/${arg#*/}" ;;
        /*) p="$arg" ;;
        *) p="$dir/$arg" ;;
      esac
      case "$p" in *'$'* | *'*'*) continue ;; esac
      p="$(_norm "$p")"
      [[ -f "$p" ]] && printf '%s\n' "$p"
    done
}

# Is $1 defined as a function anywhere in $2's source closure (including
# $2)? Prints nothing; returns 0/1. Cycle-safe.
_closure_defines() {
  local helper="$1" seen="$2" queue="$2" cur rest next
  while [[ -n "$queue" ]]; do
    cur="${queue%%$'\n'*}"
    rest="${queue#*$'\n'}"
    [[ "$rest" == "$queue" ]] && rest=""
    queue="$rest"
    grep -qE "^[[:space:]]*(function[[:space:]]+)?${helper}[[:space:]]*\(\)" \
      "$cur" 2>/dev/null && return 0
    while IFS= read -r next; do
      [[ -n "$next" ]] || continue
      printf '%s\n' "$seen" | grep -qxF "$next" && continue
      seen="$seen"$'\n'"$next"
      queue="$queue"$'\n'"$next"
    done < <(_sources_of "$cur")
  done
  return 1
}

# Files that source $1 (one level up), found by basename then confirmed by
# resolving that file's own source list.
_parents_of() {
  local target="$1" base cand
  base="$(basename "$target")"
  grep -rlE "^[[:space:]]*(source|\.)[[:space:]].*${base}" $SCAN_DIRS 2>/dev/null |
    while IFS= read -r cand; do
      [[ "$cand" == "$target" ]] && continue
      srcs="$(_sources_of "$cand")"
      printf '%s\n' "$srcs" | grep -qxF "$target" && printf '%s\n' "$cand"
    done
}

failures=""
callers_checked=0

for helper in $SHARED_HELPERS; do
  # Files that call the helper as a command, excluding its own definition
  # line and comment lines.
  callers="$(
    grep -rnE "(^|[[:space:]]|[;&|(])${helper}([[:space:]]|$)" $SCAN_DIRS 2>/dev/null |
      grep -vE ":[[:space:]]*#" |
      grep -vE "${helper}[[:space:]]*\(\)" |
      cut -d: -f1 | sort -u
  )"
  for f in $callers; do
    callers_checked=$((callers_checked + 1))
    _closure_defines "$helper" "$f" && continue
    # A partial inherits definitions from whatever sources it.
    ok=""
    for p in $(_parents_of "$f"); do
      _closure_defines "$helper" "$p" && {
        ok="yes"
        break
      }
    done
    [[ -n "$ok" ]] && continue
    failures="$failures$f calls $helper, and nothing it sources (or that sources it) defines it"$'\n'
  done
done

test_start "every caller reaches the shared helper it calls"
if [[ -z "$failures" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST ($callers_checked call sites)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  printf '%s' "$failures" | sed 's/^/      /'
fi

# A guard on the guard. If the resolver silently resolved nothing, the
# check above would pass vacuously. scripts/dot/commands/tools.sh reaches
# lib/dot/utils.sh through a "$_TOOLS_DIR/../../../" prefix, which is the
# exact shape _sources_of and _norm have to get right between them.
test_start "the source-closure resolver actually resolves"
# Collected into a variable rather than piped into `grep -q`: under
# `pipefail`, grep -q exits at the first match, the producer takes SIGPIPE,
# and the pipeline reports failure on a successful match.
resolved="$(_sources_of scripts/dot/commands/tools.sh)"
if printf '%s\n' "$resolved" | grep -qxF lib/dot/utils.sh; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: resolved $(printf '%s ' $resolved)"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
