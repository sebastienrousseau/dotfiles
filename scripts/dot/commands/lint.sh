#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Lint Command
# Wraps shellcheck and shfmt with project-specific flags

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Lint" "${1:-}"

# ── Configuration ────────────────────────────────────────────────────────────
# Flags from CLAUDE.md conventions:
#   SC flags: --severity=error -e SC1091 -e SC2030 -e SC2031
#   shfmt:    -i 2 -ci
SHELLCHECK_ARGS=(--severity=error -e SC1091 -e SC2030 -e SC2031)
SHFMT_ARGS=(-i 2 -ci)

# True only if the file's shebang names a shell that both shellcheck and shfmt
# can process. The old `grep -qiE 'shell|bash|sh'` matched loosely — "sh" hit
# "fish", and `file` output pulled in python3 scripts — so non-shell files
# landed in the lint set and produced spurious SC1071 / shfmt parse "errors".
_lint_is_shell() {
  local first interp
  first="$(head -1 "$1" 2>/dev/null)"
  case "$first" in '#!'*) ;; *) return 1 ;; esac
  interp="${first#\#!}"
  interp="${interp#"${interp%%[![:space:]]*}"}" # ltrim
  case "$interp" in
    */env[[:space:]]*)
      interp="${interp#*/env}"
      interp="${interp#"${interp%%[![:space:]]*}"}"
      interp="${interp%%[[:space:]]*}"
      ;;
    *)
      interp="${interp%%[[:space:]]*}"
      interp="${interp##*/}"
      ;;
  esac
  case "$interp" in
    sh | bash | dash | ksh | mksh | ash) return 0 ;;
    *) return 1 ;;
  esac
}

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

  # Post-Phase-4b chezmoi-tracked content lives under defaults/.
  local chezmoi_src
  chezmoi_src="$(resolve_chezmoi_source_dir)"
  [[ -z "$chezmoi_src" ]] && chezmoi_src="$src_dir"

  # dot_local/bin/executable_* scripts — shell scripts only (skip python/zsh/etc
  # by inspecting the shebang, so shellcheck/shfmt never see files they can't parse).
  while IFS= read -r -d '' f; do
    if _lint_is_shell "$f"; then
      files+=("$f")
    fi
  done < <(find "$chezmoi_src/dot_local/bin" -name 'executable_*' -type f -print0 2>/dev/null)

  # .chezmoitemplates/*.sh (non-.tmpl shell scripts)
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$chezmoi_src/.chezmoitemplates" -name '*.sh' -type f -print0 2>/dev/null)

  local total=${#files[@]}
  if [[ "$total" -eq 0 ]]; then
    ui_warn "No files" "No shell scripts found to lint"
    return 0
  fi

  local sc_errors=0
  local fmt_errors=0

  case "$mode" in
    all | check)
      # ── ShellCheck ──────────────────────────────────────────────────────
      if has_command shellcheck; then
        ui_section "ShellCheck"
        echo ""
        # One shellcheck invocation over all files (was one fork per file).
        # gcc format is one line per issue, so failing files = unique paths.
        local sc_out
        sc_out="$(shellcheck -f gcc "${SHELLCHECK_ARGS[@]}" "${files[@]}" 2>/dev/null || true)"
        if [[ -z "$sc_out" ]]; then
          ui_ok "shellcheck" "$total files clean"
        else
          printf '%s\n' "$sc_out"
          sc_errors=$(printf '%s\n' "$sc_out" | cut -d: -f1 | sort -u | grep -c .)
          ui_err "shellcheck" "$sc_errors file(s) with errors"
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
        # `shfmt -l` lists files needing formatting in one invocation
        # (was `shfmt -d` per file).
        local fmt_list
        fmt_list="$(shfmt "${SHFMT_ARGS[@]}" -l "${files[@]}" 2>/dev/null || true)"
        if [[ -z "$fmt_list" ]]; then
          ui_ok "shfmt" "$total files formatted correctly"
        else
          fmt_errors=$(printf '%s\n' "$fmt_list" | grep -c .)
          ui_err "shfmt" "$fmt_errors file(s) need formatting"
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
      # Find files needing formatting in one `shfmt -l` pass, then only
      # rewrite that (usually small) set — was `shfmt -d` per file.
      local fmt_list fixed=0
      fmt_list="$(shfmt "${SHFMT_ARGS[@]}" -l "${files[@]}" 2>/dev/null || true)"
      if [[ -z "$fmt_list" ]]; then
        ui_ok "shfmt" "All files already formatted"
      else
        while IFS= read -r f; do
          [[ -n "$f" ]] || continue
          shfmt "${SHFMT_ARGS[@]}" -w "$f"
          ui_ok "fixed" "${f#"$src_dir/"}"
          fixed=$((fixed + 1))
        done <<<"$fmt_list"
        ui_ok "shfmt" "$fixed file(s) reformatted"
      fi
      echo ""
      ;;

    *)
      ui_err "Unknown lint mode: $mode"
      echo "Usage: dot lint [--fix|-f | --check|-c]"
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
      --fix | -f) cmd_lint "fix" ;;
      --check | -c) cmd_lint "check" ;;
      *) cmd_lint "all" ;;
    esac
    ;;
  *)
    # Direct invocation (dot lint)
    case "${1:---}" in
      --fix | -f) cmd_lint "fix" ;;
      --check | -c) cmd_lint "check" ;;
      *) cmd_lint "all" ;;
    esac
    ;;
esac
