#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/ai.sh.
# Version probing for `dot ai tools`: run `<tool> --version` from a private
# scratch directory and pick the line that carries the version.

# Re-source guard: cheap short-circuit when sourced from multiple modules.
[[ "${_DOT_LIB_AI_PROBE_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_AI_PROBE_LOADED=1

# A version line: a standalone token such as 1.2, v0.94.2 or 2025.09.12-abc,
# not one embedded in a path or file name (crush_0.94.2_Darwin, /v0.94.2/).
AI_VERSION_RE='(^|[[:space:]])v?[0-9]+[.][0-9]+[^[:space:]/_]*([[:space:]]|[(]|$)'

# _ai_version_line — read `<tool> --version` output on stdin and print the
# line that carries the version: the last line with a standalone version
# token, else the first line. Install shims (the npm crush wrapper) print
# download and extraction progress before the real version line.
_ai_version_line() {
  awk -v re="$AI_VERSION_RE" 'NR == 1 { first = $0 } $0 ~ re { last = $0 }
    END { if (last != "") print last; else if (NR) print first }'
}

# _ai_probe_version <bin> [timeout-prefix] — run `<bin> --version` from a
# private scratch directory (removed afterwards) and print its version line.
# Some shims unpack downloads into the current directory (archive-XXXXXX),
# which littered whatever directory `dot ai tools` ran from.
_ai_probe_version() {
  local bin="$1" to="${2:-}" dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-probe.XXXXXX")" || return 0
  # shellcheck disable=SC2086 # $to is an optional "timeout 8" prefix
  (cd "$dir" && $to "$bin" --version </dev/null 2>/dev/null | _ai_version_line) || true
  rm -rf "$dir"
}

_ai_extract_version() {
  local bin="$1"
  local output version
  output=$(_ai_probe_version "$bin")
  version=$(printf '%s' "$output" | sed 's/^[^0-9]*//' | sed 's/[[:space:]]*$//' | sed 's/\.$//')
  [[ -n "$version" ]] && printf '%s\n' "$version" || printf 'installed\n'
}
