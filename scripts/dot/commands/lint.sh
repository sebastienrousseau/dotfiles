#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Lint Command
# Wraps shellcheck and shfmt with project-specific flags

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

dot_ui_command_banner "Lint" "${1:-}"

# ── Configuration ────────────────────────────────────────────────────────────
# Flags from CLAUDE.md conventions:
#   shellcheck: --severity=error -e SC1091 -e SC2030 -e SC2031
#   shfmt:      -i 2 -ci
SHELLCHECK_ARGS=(--severity=error -e SC1091 -e SC2030 -e SC2031)
SHFMT_ARGS=(-i 2 -ci)

cmd_lint() {
  local mode="${1:-all}"
  local src_dir
  src_dir="$(require_source_dir)"

  # Collect target files
  local -a files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$src_dir/scripts" -name '*.sh' -type f -print0 2>/dev/null)

  # install.sh
  if [[ -f "$src_dir/install.sh" ]]; then
    files+=("$src_dir/install.sh")
  fi

  # dot_local/bin/executable_* scripts (shell scripts only)
  while IFS= read -r -d '' f; do
    if file "$f" 2>/dev/null | grep -qiE 'shell|bash|sh'; then
      files+=("$f")
    elif head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash|sh)'; then
      files+=("$f")
    fi
  done < <(find "$src_dir/dot_local/bin" -name 'executable_*' -type f -print0 2>/dev/null)

  # .chezmoitemplates/*.sh (non-.tmpl shell scripts)
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$src_dir/.chezmoitemplates" -name '*.sh' -type f -print0 2>/dev/null)

  local total=${#files[@]}
  if [[ "$total" -eq 0 ]]; then
    ui_warn "No files" "No shell scripts found to lint"
    return 0
  fi

  local sc_errors=0
  local fmt_errors=0
  local sc_warnings=0

  case "$mode" in
    all | check)
      # ── ShellCheck ──────────────────────────────────────────────────────
      if has_command shellcheck; then
        ui_section "ShellCheck"
        echo ""
        local sc_fail=0
        for f in "${files[@]}"; do
          if ! shellcheck "${SHELLCHECK_ARGS[@]}" "$f" 2>/dev/null; then
            sc_fail=$((sc_fail + 1))
          fi
        done
        if [[ "$sc_fail" -eq 0 ]]; then
          ui_ok "shellcheck" "$total files clean"
        else
          sc_errors=$sc_fail
          ui_err "shellcheck" "$sc_fail file(s) with errors"
        fi
        echo ""
      else
        ui_warn "shellcheck" "not installed, skipping"
        echo ""
      fi

      # ── shfmt ───────────────────────────────────────────────────────────
      if has_command shfmt; then
        ui_section "shfmt"
        echo ""
        local fmt_fail=0
        for f in "${files[@]}"; do
          if ! shfmt "${SHFMT_ARGS[@]}" -d "$f" >/dev/null 2>&1; then
            fmt_fail=$((fmt_fail + 1))
          fi
        done
        if [[ "$fmt_fail" -eq 0 ]]; then
          ui_ok "shfmt" "$total files formatted correctly"
        else
          fmt_errors=$fmt_fail
          ui_err "shfmt" "$fmt_fail file(s) need formatting"
        fi
        echo ""
      else
        ui_warn "shfmt" "not installed, skipping"
        echo ""
      fi
      ;;

    fix)
      # ── Auto-fix with shfmt ─────────────────────────────────────────────
      if ! has_command shfmt; then
        ui_err "shfmt" "not installed — cannot auto-fix"
        exit 1
      fi
      ui_section "Auto-fixing with shfmt"
      echo ""
      local fixed=0
      for f in "${files[@]}"; do
        if ! shfmt "${SHFMT_ARGS[@]}" -d "$f" >/dev/null 2>&1; then
          shfmt "${SHFMT_ARGS[@]}" -w "$f"
          ui_ok "fixed" "${f#"$src_dir/"}"
          fixed=$((fixed + 1))
        fi
      done
      if [[ "$fixed" -eq 0 ]]; then
        ui_ok "shfmt" "All files already formatted"
      else
        ui_ok "shfmt" "$fixed file(s) reformatted"
      fi
      echo ""
      ;;

    *)
      ui_err "Unknown lint mode: $mode"
      echo "Usage: dot lint [--fix | --check]"
      exit 1
      ;;
  esac

  # ── Summary ───────────────────────────────────────────────────────────────
  ui_section "Summary"
  echo ""
  ui_info "Files scanned" "$total"
  if [[ "$sc_errors" -gt 0 ]]; then
    ui_err "ShellCheck errors" "$sc_errors"
  fi
  if [[ "$fmt_errors" -gt 0 ]]; then
    ui_err "Formatting issues" "$fmt_errors"
  fi
  if [[ "$sc_errors" -eq 0 ]] && [[ "$fmt_errors" -eq 0 ]]; then
    ui_ok "Result" "All checks passed"
  fi
  echo ""

  # Exit 1 in check mode if any errors
  if [[ "$mode" == "check" ]] && [[ $((sc_errors + fmt_errors)) -gt 0 ]]; then
    exit 1
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "${1:-}" in
  lint)
    shift
    case "${1:---}" in
      --fix) cmd_lint "fix" ;;
      --check) cmd_lint "check" ;;
      *) cmd_lint "all" ;;
    esac
    ;;
  *)
    # Direct invocation (dot lint)
    case "${1:---}" in
      --fix) cmd_lint "fix" ;;
      --check) cmd_lint "check" ;;
      *) cmd_lint "all" ;;
    esac
    ;;
esac
