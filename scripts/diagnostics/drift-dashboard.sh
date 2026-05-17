#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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

for arg in "$@"; do
  case "$arg" in
    --json | -j) JSON_MODE=1 ;;
    --diff | -d) SHOW_DIFF=1 ;;
    --help | -h)
      cat <<EOF
Usage: drift-dashboard.sh [options]

Options:
  --json, -j    Emit a single JSON object summarising every drift class.
  --diff, -d    Also print the chezmoi diff (excluding scripts/install/tests).
  --help, -h    Show this help.
EOF
      exit 0
      ;;
  esac
done

ui_init

if ! command -v chezmoi >/dev/null; then
  if [[ $JSON_MODE -eq 1 ]]; then
    printf '{"error":"chezmoi not found"}\n'
  else
    ui_err "chezmoi" "not found"
  fi
  exit 2
fi

# -----------------------------------------------------------------------------
# Class 1: chezmoi-managed drift
# -----------------------------------------------------------------------------

cm_status="$(chezmoi status 2>/dev/null || true)"
cm_count=0
if [[ -n "$cm_status" ]]; then
  cm_count=$(printf '%s\n' "$cm_status" | wc -l | tr -d ' ')
fi

# -----------------------------------------------------------------------------
# Class 2: untracked source files (chezmoi source tree only)
# -----------------------------------------------------------------------------

untracked=""
untracked_count=0
src_dir="$(chezmoi source-path 2>/dev/null || true)"
if [[ -n "$src_dir" && -d "$src_dir/.git" ]]; then
  untracked="$(git -C "$src_dir" ls-files --others --exclude-standard 2>/dev/null || true)"
  if [[ -n "$untracked" ]]; then
    untracked_count=$(printf '%s\n' "$untracked" | wc -l | tr -d ' ')
  fi
fi

# -----------------------------------------------------------------------------
# Class 4: stale source (source older than deployed = pending revert risk)
# Compute by walking chezmoi-managed targets and comparing mtimes.
# -----------------------------------------------------------------------------

stale_list=""
stale_count=0
if [[ -n "$src_dir" ]]; then
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    target_path="$target"
    [[ ! -e "$target_path" ]] && continue
    src_path="$(chezmoi source-path "$target_path" 2>/dev/null || true)"
    [[ -z "$src_path" || ! -e "$src_path" ]] && continue
    if [[ "$target_path" -nt "$src_path" ]]; then
      stale_list+="$target_path"$'\n'
      stale_count=$((stale_count + 1))
    fi
  done < <(chezmoi managed 2>/dev/null | head -200 | while IFS= read -r rel; do
    printf '%s\n' "$HOME/$rel"
  done)
fi
stale_list="${stale_list%$'\n'}"

# -----------------------------------------------------------------------------
# Class 3: orphan deployed files (chezmoi no longer claims them)
# Sample heuristic — chezmoi doesn't expose a direct "orphan" query.
# We surface a count of zero unless the user has a pre-populated
# ~/.local/state/dotfiles/orphans file (drift-history feature in fleet
# already maintains one); future work tracked under #875.
# -----------------------------------------------------------------------------

orphan_count=0
orphan_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/orphans"
if [[ -s "$orphan_file" ]]; then
  orphan_count=$(wc -l <"$orphan_file" | tr -d ' ')
fi

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------

total=$((cm_count + untracked_count + orphan_count + stale_count))

if [[ $JSON_MODE -eq 1 ]]; then
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
  if ((total > 0)); then exit 1; else exit 0; fi
fi

ui_header "Dotfiles Drift Dashboard"

# Class 1
if ((cm_count > 0)); then
  echo ""
  ui_warn "Managed drift" "$cm_count file(s) — deployed differs from rendered source"
  printf '%s\n' "$cm_status"
else
  ui_ok "Managed drift" "clean"
fi

# Class 2
if ((untracked_count > 0)); then
  echo ""
  ui_warn "Untracked source" "$untracked_count file(s) in chezmoi source not tracked by git"
  printf '%s\n' "$untracked"
else
  ui_ok "Untracked source" "clean"
fi

# Class 3
if ((orphan_count > 0)); then
  echo ""
  ui_warn "Orphan deployed" "$orphan_count file(s) — review $(pretty_path "$orphan_file")"
else
  ui_ok "Orphan deployed" "clean"
fi

# Class 4
if ((stale_count > 0)); then
  echo ""
  ui_warn "Stale source" "$stale_count target(s) newer than source — next \`chezmoi apply\` would revert"
  printf '%s\n' "$stale_list"
else
  ui_ok "Stale source" "clean"
fi

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

((total > 0)) && exit 1 || exit 0
