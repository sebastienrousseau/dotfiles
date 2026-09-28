#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles Health Check Dashboard
# Usage: dot health [--verbose|-v] [--json|-j] [--fix|-f] [--force|-F]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/log.sh"
# Deliberately NOT lib/dot/utils.sh's has_command, though it is identical.
# health.sh has to run against a minimal tree: the matrix test in
# tests/unit/diagnostics/test_diagnostics_health_matrix.sh builds one that
# symlinks ui.sh and log.sh and nothing else, because a health check whose
# own dependencies are missing is worth very little. Sourcing utils.sh here
# would pull in platform.sh, ai-install.sh and verified-download.sh and
# break in exactly the degraded tree this script exists to diagnose.
has_command() { command -v "$1" >/dev/null 2>&1; }

# Colors (fallback when gum is unavailable; respect NO_COLOR)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
  BLUE='\033[0;34m' CYAN='\033[0;36m' GRAY='\033[0;90m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' GRAY='' NC=''
fi

# Parse arguments (VERBOSE exported for potential use by sourced scripts)
export VERBOSE=false
JSON_OUTPUT=false
APPLY_FIX=false
FORCE_FIX=false
_health_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose | -v) VERBOSE=true ;;
      --fix | -f) APPLY_FIX=true ;;
      --force | -F) FORCE_FIX=true ;;
      --json | -j) JSON_OUTPUT=true ;;
    esac
    shift
  done
}
_health_parse_args "$@"

reset_stats() {
  TOTAL_CHECKS=0
  PASSED_CHECKS=0
  WARNINGS=0
  FAILURES=0
}

# Health check results
reset_stats
declare -a RESULTS=()
ui_init
use_ui="$UI_ENABLED"

header() {
  local text="$1"
  if $JSON_OUTPUT; then
    return
  fi
  if [[ "$use_ui" = "1" ]]; then
    ui_header "$text"
  else
    printf '%b\n' "${CYAN}${text}${NC}"
  fi
}

section() {
  local text="$1"
  if $JSON_OUTPUT; then
    return
  fi
  if [[ "$use_ui" = "1" ]]; then
    ui_section "$text"
  else
    printf '%b\n' "\n${BLUE}▸ $text${NC}"
  fi
}

# _health_plain <color> <glyph> <label> <name> <message>: one plain-text
# warning/failure row.
_health_plain() {
  printf "${1}${2}${NC} %-35s ${1}${3}${NC}" "$4"
  [[ -n "$5" ]] && printf " ${GRAY}%s${NC}" "$5"
  printf "\n"
}

# _health_render <name> <status> <message>: one result row.
_health_render() {
  local name="$1" status="$2" message="$3"
  if [[ "$use_ui" = "1" ]]; then
    case "$status" in
      pass) ui_ok "$name" ;;
      warn) ui_warn "$name" "$message" ;;
      fail) ui_err "$name" "$message" ;;
    esac
    return 0
  fi
  case "$status" in
    pass) printf "${GREEN}✓${NC} %-35s ${GREEN}OK${NC}\n" "$name" ;;
    warn) _health_plain "$YELLOW" "⚠" "WARNING" "$name" "$message" ;;
    fail) _health_plain "$RED" "✗" "FAILED" "$name" "$message" ;;
  esac
}

check() {
  local name="$1"
  local status="$2"
  local message="${3:-}"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  # Collect structured result for JSON output (escape quotes for valid JSON)
  local _j_name="${name//\"/\\\"}"
  local _j_status="${status//\"/\\\"}"
  local _j_message="${message//\"/\\\"}"
  RESULTS+=("{\"check\":\"${_j_name}\",\"status\":\"${_j_status}\",\"message\":\"${_j_message}\"}")

  case "$status" in
    pass) PASSED_CHECKS=$((PASSED_CHECKS + 1)) ;;
    warn) WARNINGS=$((WARNINGS + 1)) ;;
    fail) FAILURES=$((FAILURES + 1)) ;;
  esac
  if ! $JSON_OUTPUT; then
    _health_render "$name" "$status" "$message"
  fi
}

print_header() {
  if ! $JSON_OUTPUT; then
    echo ""
    ui_dot_banner "Diagnostics"
    header "Dotfiles Health Dashboard"
    echo ""
  fi
}

check_section() {
  if ! $JSON_OUTPUT; then
    echo ""
    section "$1"
    [[ "$use_ui" = "1" ]] || echo "───────────────────────────────────────────────"
  fi
}

# === Focused check sub-functions ===

check_dotfiles_core() {
  check_section "Dotfiles Core"

  if has_command chezmoi; then
    check "Chezmoi installed" "pass"
    if [[ -d "${HOME}/.local/share/chezmoi" ]] || [[ -d "${HOME}/.dotfiles" ]]; then
      check "Chezmoi source directory" "pass"
    else
      check "Chezmoi source directory" "fail" "Not found"
    fi
  else
    check "Chezmoi installed" "fail" "Not installed"
  fi

  if has_command git; then
    check "Git installed" "pass"
    if git config user.email >/dev/null 2>&1; then
      check "Git user configured" "pass"
    else
      check "Git user configured" "warn" "Email not set"
    fi
  else
    check "Git installed" "fail"
  fi
}

check_shell_env() {
  check_section "Shell Environment"
  local current_shell="${SHELL##*/}"
  local default_shell="fish"
  if [[ -f "$SCRIPT_DIR/../../defaults/.chezmoidata.toml" ]]; then
    default_shell="$(awk -F= '/^[[:space:]]*default_shell[[:space:]]*=/{split($2, value, "#"); gsub(/[ "]/, "", value[1]); print value[1]; exit}' "$SCRIPT_DIR/../../defaults/.chezmoidata.toml")"
    default_shell="${default_shell:-fish}"
  fi

  if has_command zsh; then
    check "Zsh installed" "pass"
    if [[ "$current_shell" =~ ^(zsh|fish|bash|nu|nushell)$ ]]; then
      check "Active shell" "pass" "$current_shell"
    else
      check "Active shell" "warn" "Current: $SHELL"
    fi
  else
    check "Zsh installed" "fail"
  fi

  if [[ -f "${ZINIT_HOME:-$HOME/.local/share/zinit/zinit.git}/zinit.zsh" ]] || [[ -d "${ZINIT_HOME:-$HOME/.local/share/zinit}" ]]; then
    check "Zinit plugin manager" "pass"
  elif [[ "$current_shell" == "zsh" && "$default_shell" == "zsh" ]]; then
    check "Zinit plugin manager" "warn" "Not found"
  else
    check "Zinit plugin manager" "pass" "Not required for $default_shell"
  fi

  if has_command starship; then
    check "Starship prompt" "pass"
  else
    check "Starship prompt" "warn" "Not installed"
  fi
}

check_dev_tools() {
  check_section "Development Tools"

  if has_command node; then
    local node_version
    # `|| true` is load-bearing under `set -e`: an assignment takes the exit
    # status of its command substitution, so a `node` that fails to report a
    # version aborts the entire health report mid-section — no Summary, no
    # score, rc=1. That is exactly what happened when `node` resolved to a
    # mise shim under a sandboxed HOME. A diagnostic tool must survive the
    # tools it is diagnosing.
    node_version=$(node --version 2>/dev/null || true)
    check "Node.js ($node_version)" "pass"
  else
    check "Node.js" "warn" "Not installed"
  fi

  if has_command fnm; then
    check "fnm (Node version manager)" "pass"
  elif has_command mise && has_command node; then
    check "Node version manager" "pass" "mise"
  else
    check "fnm" "warn" "Not installed"
  fi

  if has_command python3; then
    local py_version
    # pipefail is on, so this pipeline reports python3's failure even though
    # `cut` succeeds — and an assignment inherits that status, aborting the
    # report under `set -e`. Same hazard as node_version above.
    py_version=$(python3 --version 2>/dev/null | cut -d' ' -f2 || true)
    check "Python ($py_version)" "pass"
  else
    check "Python" "warn" "Not installed"
  fi

  if has_command rustc; then
    check "Rust toolchain" "pass"
  else
    check "Rust toolchain" "warn" "Not installed"
  fi

  if has_command go; then
    check "Go" "pass"
  else
    check "Go" "warn" "Not installed"
  fi
}

check_cli_tools() {
  check_section "CLI Tools"

  local tools=("fzf" "ripgrep:rg" "fd" "bat" "eza" "zoxide" "atuin" "delta" "jq" "yq" "sops" "mise" "just" "zellij" "hyperfine")
  for tool in "${tools[@]}"; do
    local name="${tool%%:*}"
    local cmd="${tool##*:}"
    if has_command "$cmd"; then
      check "$name" "pass"
    else
      check "$name" "warn" "Not installed"
    fi
  done
}

check_editors() {
  check_section "Editors"

  if has_command nvim; then
    check "Neovim" "pass"
    if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy" ]]; then
      check "Neovim plugins (lazy.nvim)" "pass"
    else
      check "Neovim plugins" "warn" "Lazy.nvim not found"
    fi
  else
    check "Neovim" "warn" "Not installed"
  fi
}

# Whether a Nerd Font is installed: fc-list, then the macOS and XDG font dirs.
_health_nerd_font() {
  local fc_list_output=""
  if command -v fc-list >/dev/null 2>&1; then
    fc_list_output="$(fc-list 2>/dev/null || true)"
    [[ "$fc_list_output" == *"Nerd Font"* ]] && return 0
  fi
  if [[ -d "$HOME/Library/Fonts" ]] && compgen -G "$HOME/Library/Fonts/"'*Nerd*' >/dev/null 2>&1; then
    return 0
  fi
  [[ -d "$HOME/.local/share/fonts" ]] && compgen -G "$HOME/.local/share/fonts/"'*Nerd*' >/dev/null 2>&1
}

check_terminal() {
  check_section "Terminal"

  if has_command ghostty || [[ -d "/Applications/Ghostty.app" ]]; then
    check "Ghostty terminal" "pass"
  else
    check "Ghostty terminal" "warn" "Not installed"
  fi

  if _health_nerd_font; then
    check "Nerd Font available" "pass"
  else
    check "Nerd Font available" "warn" "Not installed"
  fi
}

_health_check_age() {
  local age_identity="${HOME}/.config/chezmoi/key.txt" configured_identity=""
  if ! has_command age; then
    check "Age encryption" "warn" "Not installed"
    return 0
  fi
  check "Age encryption" "pass"
  if has_command chezmoi && has_command jq; then
    configured_identity=$(chezmoi dump-config --format=json 2>/dev/null | jq -r '.age.identity // empty' 2>/dev/null || true)
    [[ -z "$configured_identity" ]] || age_identity="${configured_identity/#\~/$HOME}"
  fi
  if [[ -f "$age_identity" ]]; then
    check "Age key configured" "pass"
  else
    check "Age key configured" "warn" "Key not found"
  fi
}

# Fills the caller's ssh_keys: the conventional names, then every private
# key that has a .pub beside it.
_health_ssh_keys() {
  local public_key key existing_key
  ssh_keys=("$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ed25519_sk")
  for public_key in "$HOME/.ssh/"*.pub; do
    [[ -f "$public_key" && -f "${public_key%.pub}" ]] || continue
    key="${public_key%.pub}"
    for existing_key in "${ssh_keys[@]}"; do
      [[ "$existing_key" != "$key" ]] || continue 2
    done
    ssh_keys+=("$key")
  done
}

_health_check_ssh() {
  local -a ssh_keys=()
  local key perms keys_found=false
  _health_ssh_keys
  for key in "${ssh_keys[@]}"; do
    [[ ! -f "$key" ]] || keys_found=true
  done
  if $keys_found; then
    check "SSH keys present" "pass"
  else
    check "SSH keys present" "warn" "No keys found"
  fi

  # Check SSH key permissions
  for key in "${ssh_keys[@]}"; do
    [[ -f "$key" ]] || continue
    # Same hazard as node_version above: if BOTH stat spellings fail (a
    # platform with neither GNU nor BSD stat), the assignment is non-zero
    # and `set -e` kills the report. Empty perms falls through to the
    # "should be 600" warning, which is the right answer when the mode
    # cannot be read.
    perms=$(stat -c '%a' "$key" 2>/dev/null || stat -f '%Lp' "$key" 2>/dev/null || true)
    if [[ "$perms" != "600" && "$perms" != "400" ]]; then
      check "SSH key perms (${key##*/})" "warn" "mode $perms (should be 600)"
    else
      check "SSH key perms (${key##*/})" "pass"
    fi
  done
}

# SSH commit signing when fully configured, else GPG secret keys.
_health_check_signing() {
  local signing_format signing_key allowed_signers
  if ! has_command gpg; then
    check "GPG" "warn" "Not installed"
    return 0
  fi
  signing_format="$(git config --global gpg.format 2>/dev/null || true)"
  signing_key="$(git config --global user.signingkey 2>/dev/null || true)"
  allowed_signers="$(git config --global gpg.ssh.allowedSignersFile 2>/dev/null || echo "$HOME/.config/git/allowed_signers")"

  if [[ "$signing_format" == "ssh" ]] && [[ -n "$signing_key" ]] && [[ -f "${signing_key/#\~/$HOME}" ]] && [[ -f "${allowed_signers/#\~/$HOME}" ]]; then
    check "Git signing" "pass" "ssh"
  elif gpg --list-secret-keys 2>/dev/null | grep -q sec; then
    check "GPG keys" "pass"
  else
    check "GPG keys" "warn" "No secret keys"
  fi
}

check_security() {
  check_section "Security"
  _health_check_age
  _health_check_ssh
  _health_check_signing
}

check_performance() {
  check_section "Performance"

  if has_command zsh; then
    local startup_time
    # Startup timing is diagnostic only. A user's interactive configuration
    # may exit non-zero or omit a `real` row, which must not abort health under
    # `set -euo pipefail` before the summary is printed.
    startup_time=$({ time zsh -i -c exit; } 2>&1 | awk '/real/ { print $2; exit }' | sed 's/[ms]//g' || true)
    if [[ -n "$startup_time" ]]; then
      check "Shell startup time" "pass"
    else
      check "Shell startup time" "warn" "Could not measure"
    fi
  fi
}

check_config_directories() {
  check_section "Config Directories"

  local config_dirs=(
    "$HOME/.config/shell"
    "$HOME/.config/nvim"
    "$HOME/.config/git"
  )
  local found=0 total=${#config_dirs[@]}

  for dir in "${config_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      check "Config: ${dir##*/}" "pass"
      found=$((found + 1))
    else
      check "Config: ${dir##*/}" "warn" "Not found"
    fi
  done

  if [[ $found -eq $total ]]; then
    check "Config directories" "pass"
  elif [[ $found -gt 0 ]]; then
    check "Config directories" "warn" "$found/$total present"
  else
    check "Config directories" "fail" "None found"
  fi
}

# Chezmoi status. The two-character prefix encodes both directions:
#   col 1 = last-applied state vs actual    (was the file edited in
#                                            place since last apply?)
#   col 2 = actual state vs target          (what `chezmoi apply`
#                                            would still change)
# Only col 2 matters for "is $HOME out of sync with the source" —
# col 1 alone just means the source repo has uncommitted edits,
# which is normal during development and not something the user
# needs warned about via the health dashboard.
_health_chezmoi_sync() {
  local status_output applicable source_only
  if ! has_command chezmoi; then
    check "Chezmoi sync" "warn" "Not installed, skipped"
    return 0
  fi
  # --exclude=always: always-run scripts are pending by design, not drift.
  status_output=$(chezmoi status --exclude=always 2>/dev/null || echo "")
  if [[ -z "$status_output" ]]; then
    check "Chezmoi sync" "pass"
    return 0
  fi
  # Count only entries where column 2 is non-space (apply would do something).
  applicable=$(printf '%s\n' "$status_output" | awk 'substr($0,2,1)!=" "' | wc -l | tr -d ' ')
  if [[ "$applicable" -eq 0 ]]; then
    # All drift is source-only (unstaged edits in the source repo).
    # That's not a sync issue; mention it but pass.
    source_only=$(printf '%s\n' "$status_output" | wc -l | tr -d ' ')
    check "Chezmoi sync" "pass" "$source_only source-only edit(s) (run 'chezmoi diff' to inspect)"
  else
    check "Chezmoi sync" "warn" "$applicable file(s) out of sync"
  fi
}

_health_git_tree() {
  local dotfiles_dir="${HOME}/.dotfiles" git_status="" changes
  if [[ ! -d "$dotfiles_dir/.git" ]]; then
    check "Git working tree" "warn" "Not a git repo"
    return 0
  fi
  git_status=$(git -C "$dotfiles_dir" status --porcelain 2>/dev/null || echo "")
  if [[ -z "$git_status" ]]; then
    check "Git working tree" "pass"
  else
    changes=$(printf '%s\n' "$git_status" | wc -l | tr -d ' ')
    check "Git working tree" "pass" "$changes local change(s)"
  fi
}

check_sync_status() {
  check_section "Sync Status"
  _health_chezmoi_sync
  _health_git_tree
}

# === Orchestrator ===
run_checks() {
  check_dotfiles_core
  check_shell_env
  check_dev_tools
  check_cli_tools
  check_editors
  check_terminal
  check_security
  check_config_directories
  check_sync_status
  check_performance
}

_health_summary_json() {
  local score="$1" result i=0
  printf '{\n'
  printf '  "total": %d,\n' "$TOTAL_CHECKS"
  printf '  "passed": %d,\n' "$PASSED_CHECKS"
  printf '  "warnings": %d,\n' "$WARNINGS"
  printf '  "failures": %d,\n' "$FAILURES"
  printf '  "score": %d,\n' "$score"
  printf '  "results": [\n'
  for result in "${RESULTS[@]}"; do
    if [[ $i -gt 0 ]]; then
      printf ',\n'
    fi
    printf '    %s' "$result"
    i=$((i + 1))
  done
  printf '\n  ]\n'
  printf '}\n'
}

_health_summary_counts() {
  if [[ "$use_ui" = "1" ]]; then
    printf "  %-12s %s\n" "Total checks:" "${TOTAL_CHECKS}"
    printf "  %-12s %s\n" "Passed:" "$(gum style --foreground 2 "$PASSED_CHECKS")"
    printf "  %-12s %s\n" "Warnings:" "$(gum style --foreground 3 "$WARNINGS")"
    printf "  %-12s %s\n" "Failures:" "$(gum style --foreground 1 "$FAILURES")"
  else
    printf '%b\n' "  Total checks:  ${TOTAL_CHECKS}"
    printf '%b\n' "  ${GREEN}Passed:${NC}        ${PASSED_CHECKS}"
    printf '%b\n' "  ${YELLOW}Warnings:${NC}      ${WARNINGS}"
    printf '%b\n' "  ${RED}Failures:${NC}      ${FAILURES}"
  fi
  echo ""
}

# _health_band <score> <good> <fair> <poor>: the value for the score's band
# (>= 80, >= 60, below).
_health_band() {
  if [[ $1 -ge 80 ]]; then
    printf '%s' "$2"
  elif [[ $1 -ge 60 ]]; then
    printf '%s' "$3"
  else
    printf '%s' "$4"
  fi
}

# Health score bar
_health_score_bar() {
  local score="$1" bar_width=30 filled empty filled_bar="" empty_bar="" i
  filled=$((score * bar_width / 100))
  empty=$((bar_width - filled))
  for ((i = 0; i < filled; i++)); do
    filled_bar+="${_GL_BAR_FILL}"
  done
  for ((i = 0; i < empty; i++)); do
    empty_bar+="${_GL_BAR_EMPTY}"
  done

  if [[ "$use_ui" = "1" ]]; then
    printf "  Health Score: [%s%s] %s%%\n\n" \
      "$(gum style --foreground "$(_health_band "$score" 2 3 1)" "$filled_bar")" \
      "$empty_bar" \
      "$score"
  else
    printf "  Health Score: ["
    printf '%s' "$(_health_band "$score" "${GREEN}" "${YELLOW}" "${RED}")"
    printf '%s' "$filled_bar"
    printf '%s' "${NC}"
    printf '%s' "$empty_bar"
    printf "] %s%%\n\n" "${score}"
  fi
}

_health_verdict() {
  local score="$1"
  if [[ $score -ge 90 ]]; then
    printf '%b\n' "  ${GREEN}⚡ Excellent! Your dotfiles are in great shape.${NC}"
  elif [[ $score -ge 70 ]]; then
    printf '%b\n' "  ${GREEN}✓ Good! Minor improvements possible.${NC}"
  elif [[ $score -ge 50 ]]; then
    printf '%b\n' "  ${YELLOW}⚠ Fair. Consider addressing warnings.${NC}"
  else
    printf '%b\n' "  ${RED}✗ Needs attention. Multiple issues found.${NC}"
  fi
  echo ""
  if [[ $WARNINGS -gt 0 || $FAILURES -gt 0 ]]; then
    printf '%b\n' "  ${CYAN}Tip:${NC} Run 'dot health --fix' to auto-repair common issues."
    echo ""
  fi
}

print_summary() {
  local score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
  if $JSON_OUTPUT; then
    _health_summary_json "$score"
  else
    echo ""
    header "Summary"
    echo ""
    _health_summary_counts
    _health_score_bar "$score"
    _health_verdict "$score"
  fi
  dot_log info "health_complete" "score=$score" "total=$TOTAL_CHECKS"
  dot_metric "health_score" "$score" "percent"
}

# --fix: run heal.sh (with --force when asked), then re-run every check.
_health_fix() {
  local heal_script="$SCRIPT_DIR/../ops/heal.sh"
  if ! $JSON_OUTPUT; then
    header "Auto-Remediation"
    echo ""
  fi
  if [[ -f "$heal_script" ]]; then
    if $FORCE_FIX; then
      bash "$heal_script" --force || true
    else
      bash "$heal_script" || true
    fi
  elif ! $JSON_OUTPUT; then
    printf '%b\n' "${YELLOW}⚠${NC} heal.sh not found, skipping auto-fix."
  fi
  reset_stats
  run_checks
}

# Main
_health_main() {
  export DOT_COMMAND="health"
  print_header
  run_checks
  if $APPLY_FIX; then
    _health_fix
  fi
  print_summary
}

_health_main
