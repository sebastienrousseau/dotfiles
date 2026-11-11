#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# AI Steering Patterns Management.
# Usage: dot ai pattern list|show|edit [name]
#        dot ai pattern export --hc [--agent AGENT] [name...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/sdk.sh
source "${DOT_SDK:-$SCRIPT_DIR/../../../lib/dot}/sdk.sh"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"
mkdir -p "$PATTERN_DIR"

command="${1:-list}"
name="${2:-}"

_pattern_usage() {
  echo "Usage: dot ai pattern list|show|edit [name]"
  echo "       dot ai pattern export --hc [--agent AGENT] [name...]"
  exit 1
}

# _pattern_names: every pattern, one name a line.
_pattern_names() {
  local f
  for f in "$PATTERN_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    f="${f##*/}"
    echo "${f%.md}"
  done
}

# _pattern_hc_template NAME AGENT: pattern NAME as a herdr-core template:
# the first heading (without "Identity:") describes it, AGENT runs it, and
# an agent whose hooks dot cli hook install wires (claude, codex, gemini)
# reports its state, so hc waits for that; any other gets ready: quiet.
# defaults/.chezmoitemplates/hc-template renders the shipped ones the same.
_pattern_hc_template() {
  local file="$PATTERN_DIR/$1.md" title
  title="$(sed -n '1{s/^#* *//;s/^Identity: *//;p;}' "$file")"
  printf -- '---\ndescription: %s\ncommand: %s\n' "${title:-$1}" "$2"
  [[ " claude codex gemini " == *" $2 "* ]] || printf 'ready: quiet\n'
  printf -- '---\n'
  cat "$file"
}

# _pattern_export_opts ARG...: sets EXPORT_AGENT and EXPORT_NAMES from
# --hc [--agent AGENT] [NAME...]; usage on anything else, or no --hc.
_pattern_export_opts() {
  local hc=""
  EXPORT_AGENT=claude EXPORT_NAMES=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hc) hc=1 && shift ;;
      --agent)
        [[ $# -ge 2 ]] || _pattern_usage
        EXPORT_AGENT="$2"
        shift 2
        ;;
      -*) _pattern_usage ;;
      *) EXPORT_NAMES+=("$1") && shift ;;
    esac
  done
  [[ -n "$hc" ]] || _pattern_usage
}

# _pattern_export --hc [--agent AGENT] [NAME...]: write each pattern (all by
# default) to herdr-core's templates directory, for hc run NAME "<task>".
_pattern_export() {
  local dir name
  _pattern_export_opts "$@"
  if [[ ${#EXPORT_NAMES[@]} -eq 0 ]]; then
    while IFS= read -r name; do EXPORT_NAMES+=("$name"); done < <(_pattern_names)
  fi
  dir="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-core/templates"
  mkdir -p "$dir"
  for name in "${EXPORT_NAMES[@]}"; do
    [[ -f "$PATTERN_DIR/$name.md" ]] || {
      ui_err "Pattern not found" "$name"
      exit 1
    }
    _pattern_hc_template "$name" "$EXPORT_AGENT" >"$dir/$name.md"
    ui_ok "$name" "$dir/$name.md (hc run $name \"<task>\")"
  done
}

_view_pattern() {
  local pat_name="$1" pattern_file
  if [[ -z "$pat_name" ]]; then
    ui_err "Missing pattern name" "Usage: dot ai pattern show <name>"
    exit 1
  fi
  pattern_file="$PATTERN_DIR/${pat_name}.md"
  if [[ ! -f "$pattern_file" ]]; then
    ui_err "Pattern not found" "$pat_name"
    exit 1
  fi
  ui_header "Pattern: $pat_name"
  if has_command glow && glow --version >/dev/null 2>&1; then
    glow "$pattern_file"
  else
    cat "$pattern_file"
  fi
}

case "$command" in
  list)
    ui_header "AI Steering Patterns"
    _pattern_names | while read -r p; do
      ui_bullet "$p"
    done
    ;;
  view)
    _view_pattern "$name"
    ;;
  edit)
    if [[ -z "$name" ]]; then
      ui_err "Missing pattern name" "Usage: dot ai pattern edit <name>"
      exit 1
    fi
    pattern_file="$PATTERN_DIR/${name}.md"
    ${EDITOR:-nvim} "$pattern_file"
    ;;
  export)
    shift
    _pattern_export "$@"
    ;;
  *)
    _pattern_usage
    ;;
esac
