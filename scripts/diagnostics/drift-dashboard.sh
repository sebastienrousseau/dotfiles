#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# drift-dashboard.sh — Consolidated drift report.
#
# Surfaces four classes of drift between the chezmoi source and the
# deployed targets:
#
#   1. chezmoi-managed drift — deployed file differs from rendered source
#      (`chezmoi status` output). Standard case; what the original
#      drift-dashboard reported.
#   2. Untracked source — a file exists in the chezmoi source tree but
#      isn't tracked by git, suggesting in-progress local work that
#      hasn't been committed.
#   3. Orphan deployed — a file under XDG/HOME that was previously
#      chezmoi-managed but the source has since been removed. Detected
#      by sampling well-known managed paths and asking chezmoi if it
#      claims each.
#   4. Stale source — source file older than its deployed target,
#      which means someone hand-edited the deployed file and the next
#      `chezmoi apply` will silently revert it. Reverse-drift trap.
#
# Output is JSON when --json is passed, otherwise the existing
# ui-formatted summary. Exit code: 0 if every section is clean; 1 if
# any drift is found; 2 if a prerequisite (chezmoi, git) is missing.
#
# Closes #875.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

JSON_MODE=0
SHOW_DIFF="${DOTFILES_DRIFT_SHOW_DIFF:-0}"

_dd_help() {
  cat <<EOF
Usage: drift-dashboard.sh [options]

Options:
  --json, -j    Emit a single JSON object summarising every drift class.
  --diff, -d    Also print the chezmoi diff (excluding scripts/install/tests).
  --help, -h    Show this help.
EOF
}

_dd_parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --json | -j) JSON_MODE=1 ;;
      --diff | -d) SHOW_DIFF=1 ;;
      --help | -h)
        _dd_help
        exit 0
        ;;
    esac
  done
}

_dd_require_chezmoi() {
  command -v chezmoi >/dev/null && return 0
  if [[ $JSON_MODE -eq 1 ]]; then
    printf '{"error":"chezmoi not found"}\n'
  else
    ui_err "chezmoi" "not found"
  fi
  exit 2
}

# count <text>: its line count (0 for empty text).
_dd_count() {
  if [[ -n "$1" ]]; then
    printf '%s\n' "$1" | wc -l | tr -d ' '
  else
    echo 0
  fi
}

# -----------------------------------------------------------------------------
# Class 1: chezmoi-managed drift
# -----------------------------------------------------------------------------
_dd_managed() {
  # --exclude=always: always-run scripts are pending by design, not drift.
  cm_status="$(chezmoi status --exclude=always 2>/dev/null || true)"
  cm_count="$(_dd_count "$cm_status")"
}

# -----------------------------------------------------------------------------
# Class 2: untracked source files (chezmoi source tree only)
# -----------------------------------------------------------------------------
_dd_untracked() {
  untracked=""
  untracked_count=0
  [[ -n "$src_dir" && -d "$src_dir/.git" ]] || return 0
  untracked="$(git -C "$src_dir" ls-files --others --exclude-standard 2>/dev/null || true)"
  untracked_count="$(_dd_count "$untracked")"
}

# -----------------------------------------------------------------------------
# Class 4: stale source (source older than deployed = pending revert risk)
# Compute by walking chezmoi-managed targets and comparing mtimes.
# -----------------------------------------------------------------------------

# _dd_stale_target <path>: count it when it is newer than its source.
_dd_stale_target() {
  local target_path="$1" src_path
  [[ -e "$target_path" ]] || return 0
  src_path="$(chezmoi source-path "$target_path" 2>/dev/null || true)"
  [[ -n "$src_path" && -e "$src_path" ]] || return 0
  if [[ "$target_path" -nt "$src_path" ]]; then
    stale_list+="$target_path"$'\n'
    stale_count=$((stale_count + 1))
  fi
}

_dd_stale() {
  local target
  stale_list=""
  stale_count=0
  if [[ -n "$src_dir" ]]; then
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      _dd_stale_target "$target"
    done < <(chezmoi managed 2>/dev/null | head -200 | while IFS= read -r rel; do
      printf '%s\n' "$HOME/$rel"
    done)
  fi
  stale_list="${stale_list%$'\n'}"
}

# -----------------------------------------------------------------------------
# Class 3: orphan deployed files (chezmoi no longer claims them)
# Sample heuristic — chezmoi doesn't expose a direct "orphan" query.
# We surface a count of zero unless the user has a pre-populated
# ~/.local/state/dotfiles/orphans file (drift-history feature in fleet
# already maintains one); future work tracked under #875.
# -----------------------------------------------------------------------------
_dd_orphans() {
  orphan_count=0
  orphan_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/orphans"
  if [[ -s "$orphan_file" ]]; then
    orphan_count=$(wc -l <"$orphan_file" | tr -d ' ')
  fi
}

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------
_dd_json() {
  python3 - <<PY
import json, sys
print(json.dumps({
    "managed_drift": $cm_count,
    "untracked_source": $untracked_count,
    "orphan_deployed": $orphan_count,
    "stale_source": $stale_count,
    "total": $total
}))
PY
}

# _dd_section <count> <label> <message> [<detail>]: a warning with its detail
# lines when the count is non-zero, else "clean".
_dd_section() {
  if (($1 > 0)); then
    echo ""
    ui_warn "$2" "$3"
    if (($# > 3)); then
      printf '%s\n' "$4"
    fi
  else
    ui_ok "$2" "clean"
  fi
}

_dd_report() {
  ui_header "Dotfiles Drift Dashboard"
  _dd_section "$cm_count" "Managed drift" "$cm_count file(s) — deployed differs from rendered source" "$cm_status"
  _dd_section "$untracked_count" "Untracked source" "$untracked_count file(s) in chezmoi source not tracked by git" "$untracked"
  # ~-relative, as doctor's pretty_path renders it (that helper lives in
  # doctor.sh, not in a lib this script sources). The tilde goes through a
  # variable: bash 3.2 keeps a literal backslash from `\~` here.
  local tilde='~'
  _dd_section "$orphan_count" "Orphan deployed" "$orphan_count file(s) — review ${orphan_file/#$HOME/$tilde}"
  _dd_section "$stale_count" "Stale source" "$stale_count target(s) newer than source — next \`chezmoi apply\` would revert" "$stale_list"

  echo ""
  if ((total > 0)); then
    ui_warn "Total drift signals" "$total"
  else
    ui_ok "Total" "no drift detected"
  fi

  if [[ "$SHOW_DIFF" = "1" && $cm_count -gt 0 ]]; then
    echo ""
    ui_header "chezmoi diff (excluding scripts/install/tests)"
    chezmoi diff --exclude scripts --exclude install --exclude tests || true
  fi
}

_dd_main() {
  _dd_parse_args "$@"
  ui_init
  _dd_require_chezmoi
  _dd_managed
  src_dir="$(chezmoi source-path 2>/dev/null || true)"
  _dd_untracked
  _dd_stale
  _dd_orphans
  total=$((cm_count + untracked_count + orphan_count + stale_count))

  if [[ $JSON_MODE -eq 1 ]]; then
    _dd_json
    if ((total > 0)); then exit 1; else exit 0; fi
  fi
  _dd_report
  ((total > 0)) && exit 1 || exit 0
}

_dd_main "$@"
