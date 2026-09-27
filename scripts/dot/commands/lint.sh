#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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

# Fills the caller's files array: scripts/**/*.sh, install.sh, the shell
# executables under dot_local/bin, and .chezmoitemplates/**/*.sh.
_lint_collect() {
  local src_dir="$1" chezmoi_src f
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$src_dir/scripts" -name '*.sh' -type f -print0 2>/dev/null)

  # install.sh
  if [[ -f "$src_dir/install.sh" ]]; then
    files+=("$src_dir/install.sh")
  fi

  # Post-Phase-4b chezmoi-tracked content lives under defaults/.
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
}

# ── ShellCheck ──────────────────────────────────────────────────────
# One shellcheck invocation over all files (was one fork per file).
# gcc format is one line per issue, so failing files = unique paths.
# Sets the caller's sc_errors.
_lint_shellcheck() {
  local sc_out
  if ! has_command shellcheck; then
    ui_warn "shellcheck" "not installed, skipping"
    echo ""
    return 0
  fi
  ui_section "ShellCheck"
  echo ""
  sc_out="$(shellcheck -f gcc "${SHELLCHECK_ARGS[@]}" "${files[@]}" 2>/dev/null || true)"
  if [[ -z "$sc_out" ]]; then
    ui_ok "shellcheck" "$total files clean"
  else
    printf '%s\n' "$sc_out"
    sc_errors=$(printf '%s\n' "$sc_out" | cut -d: -f1 | sort -u | grep -c .)
    ui_err "shellcheck" "$sc_errors file(s) with errors"
  fi
  echo ""
}

# ── shfmt ───────────────────────────────────────────────────────────
# `shfmt -l` lists files needing formatting in one invocation (was
# `shfmt -d` per file). Sets the caller's fmt_errors.
_lint_shfmt() {
  local fmt_list
  if ! has_command shfmt; then
    ui_warn "shfmt" "not installed, skipping"
    echo ""
    return 0
  fi
  ui_section "shfmt"
  echo ""
  fmt_list="$(shfmt "${SHFMT_ARGS[@]}" -l "${files[@]}" 2>/dev/null || true)"
  if [[ -z "$fmt_list" ]]; then
    ui_ok "shfmt" "$total files formatted correctly"
  else
    fmt_errors=$(printf '%s\n' "$fmt_list" | grep -c .)
    ui_err "shfmt" "$fmt_errors file(s) need formatting"
  fi
  echo ""
}

# ── Auto-fix with shfmt ─────────────────────────────────────────────
# Find files needing formatting in one `shfmt -l` pass, then only
# rewrite that (usually small) set — was `shfmt -d` per file.
_lint_fix() {
  local src_dir="$1" fmt_list f fixed=0
  if ! has_command shfmt; then
    ui_err "shfmt" "not installed — cannot auto-fix"
    exit 1
  fi
  ui_section "Auto-fixing with shfmt"
  echo ""
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
}

# ── Summary ───────────────────────────────────────────────────────────
_lint_summary() {
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
}

cmd_lint() {
  local mode="${1:-all}" src_dir total sc_errors=0 fmt_errors=0
  local -a files=()
  src_dir="$(require_source_dir)"
  _lint_collect "$src_dir"

  total=${#files[@]}
  if [[ "$total" -eq 0 ]]; then
    ui_warn "No files" "No shell scripts found to lint"
    return 0 # mutation: ignore unreachable in a checkout: lint.sh itself is one of the scripts/*.sh it collects
  fi

  case "$mode" in
    all | check)
      _lint_shellcheck
      _lint_shfmt
      ;;
    fix) _lint_fix "$src_dir" ;;
    *)
      ui_err "Unknown lint mode: $mode"
      echo "Usage: dot lint [--fix|-f | --check|-c]"
      exit 1 # mutation: ignore unreachable from the CLI: the dispatcher only passes all/check/fix
      ;;
  esac
  _lint_summary

  # Exit 1 in check mode if any errors
  if [[ "$mode" == "check" ]] && [[ $((sc_errors + fmt_errors)) -gt 0 ]]; then
    exit 1
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
# `dot lint …` or direct invocation.
if [[ "${1:-}" == lint ]]; then
  shift
fi
case "${1:---}" in
  --fix | -f) cmd_lint "fix" ;;
  --check | -c) cmd_lint "check" ;;
  *) cmd_lint "all" ;;
esac
