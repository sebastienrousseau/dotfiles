#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles Health Check Dashboard
# Usage: dot health [--verbose|-v] [--json|-j] [--fix|-f] [--force|-F]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/log.sh"

# Portable has_command (self-contained; no dependency on utils.sh)
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
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose | -v)
      VERBOSE=true
      shift
      ;;
    --fix | -f)
      APPLY_FIX=true
      shift
      ;;
    --force | -F)
      FORCE_FIX=true
      shift
      ;;
    --json | -j)
      JSON_OUTPUT=true
      shift
      ;;
    *) shift ;;
  esac
done

reset_stats() {
  TOTAL_CHECKS=0
  PASSED_CHECKS=0
  WARNINGS=0
  FAILURES=0
}

# Health check results
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
FAILURES=0
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
    pass)
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      # shellcheck disable=SC2034
      if ! $JSON_OUTPUT; then
        if [[ "$use_ui" = "1" ]]; then
          ui_ok "$name"
        else
          printf "${GREEN}✓${NC} %-35s ${GREEN}OK${NC}\n" "$name"
        fi
      fi
      ;;
    warn)
      WARNINGS=$((WARNINGS + 1))
      # shellcheck disable=SC2034
      if ! $JSON_OUTPUT; then
        if [[ "$use_ui" = "1" ]]; then
          ui_warn "$name" "$message"
        else
          printf "${YELLOW}⚠${NC} %-35s ${YELLOW}WARNING${NC}"
          [[ -n "$message" ]] && printf " ${GRAY}%s${NC}" "$message"
          printf "\n"
        fi
      fi
      ;;
    fail)
      FAILURES=$((FAILURES + 1))
      # shellcheck disable=SC2034
      if ! $JSON_OUTPUT; then
        if [[ "$use_ui" = "1" ]]; then
          ui_err "$name" "$message"
        else
          printf "${RED}✗${NC} %-35s ${RED}FAILED${NC}"
          [[ -n "$message" ]] && printf " ${GRAY}%s${NC}" "$message"
          printf "\n"
        fi
      fi
      ;;
  esac
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
    if [[ "$use_ui" = "1" ]]; then
      :
    else
      echo "───────────────────────────────────────────────"
    fi
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

  if [[ -d "${ZINIT_HOME:-$HOME/.local/share/zinit}" ]]; then
    check "Zinit plugin manager" "pass"
  elif [[ "$current_shell" == "zsh" ]]; then
    check "Zinit plugin manager" "warn" "Not found"
  else
    check "Zinit plugin manager" "pass" "Not required for $current_shell"
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
    node_version=$(node --version 2>/dev/null)
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
    py_version=$(python3 --version 2>/dev/null | cut -d' ' -f2)
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

check_terminal() {
  check_section "Terminal"

  if has_command ghostty || [[ -d "/Applications/Ghostty.app" ]]; then
    check "Ghostty terminal" "pass"
  else
    check "Ghostty terminal" "warn" "Not installed"
  fi

  local font_found=false
  if command -v fc-list >/dev/null 2>&1; then
    local fc_list_output=""
    fc_list_output="$(fc-list 2>/dev/null || true)"
    if [[ "$fc_list_output" == *"Nerd Font"* ]]; then
      font_found=true
    fi
  fi
  if [[ "$font_found" != true ]] && [[ -d "$HOME/Library/Fonts" ]] && compgen -G "$HOME/Library/Fonts/"'*Nerd*' >/dev/null 2>&1; then
    font_found=true
  elif [[ "$font_found" != true ]] && [[ -d "$HOME/.local/share/fonts" ]] && compgen -G "$HOME/.local/share/fonts/"'*Nerd*' >/dev/null 2>&1; then
    font_found=true
  fi

  if $font_found; then
    check "Nerd Font available" "pass"
  else
    check "Nerd Font available" "warn" "Not installed"
  fi
}

check_security() {
  check_section "Security"

  if has_command age; then
    check "Age encryption" "pass"
    if [[ -f "${HOME}/.config/chezmoi/key.txt" ]]; then
      check "Age key configured" "pass"
    else
      check "Age key configured" "warn" "Key not found"
    fi
  else
    check "Age encryption" "warn" "Not installed"
  fi

  if [[ -f "${HOME}/.ssh/id_ed25519" ]] || [[ -f "${HOME}/.ssh/id_rsa" ]]; then
    check "SSH keys present" "pass"
  else
    check "SSH keys present" "warn" "No keys found"
  fi

  # Check SSH key permissions
  for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ed25519_sk"; do
    if [[ -f "$key" ]]; then
      local perms
      perms=$(stat -c '%a' "$key" 2>/dev/null || stat -f '%Lp' "$key" 2>/dev/null)
      if [[ "$perms" != "600" && "$perms" != "400" ]]; then
        check "SSH key perms (${key##*/})" "warn" "mode $perms (should be 600)"
      else
        check "SSH key perms (${key##*/})" "pass"
      fi
    fi
  done

  if has_command gpg; then
    local signing_format signing_key allowed_signers
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
  else
    check "GPG" "warn" "Not installed"
  fi
}

check_performance() {
  check_section "Performance"

  if has_command zsh; then
    local startup_time
    startup_time=$({ time zsh -i -c exit; } 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]//g')
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

check_sync_status() {
  check_section "Sync Status"

  # Chezmoi status
  if has_command chezmoi; then
    local status_output
    status_output=$(chezmoi status 2>/dev/null || echo "")
    if [[ -z "$status_output" ]]; then
      check "Chezmoi sync" "pass"
    else
      local changes
      changes=$(printf '%s\n' "$status_output" | wc -l | tr -d ' ')
      check "Chezmoi sync" "warn" "$changes file(s) out of sync"
    fi
  else
    check "Chezmoi sync" "warn" "Not installed, skipped"
  fi

  # Git status
  local dotfiles_dir="${HOME}/.dotfiles"
  if [[ -d "$dotfiles_dir/.git" ]]; then
    local git_status=""
    git_status=$(git -C "$dotfiles_dir" status --porcelain 2>/dev/null || echo "")
    if [[ -z "$git_status" ]]; then
      check "Git working tree" "pass"
    else
      local changes
      changes=$(printf '%s\n' "$git_status" | wc -l | tr -d ' ')
      check "Git working tree" "pass" "$changes local change(s)"
    fi
  else
    check "Git working tree" "warn" "Not a git repo"
  fi
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

print_summary() {
  local score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

  if $JSON_OUTPUT; then
    printf '{\n'
    printf '  "total": %d,\n' "$TOTAL_CHECKS"
    printf '  "passed": %d,\n' "$PASSED_CHECKS"
    printf '  "warnings": %d,\n' "$WARNINGS"
    printf '  "failures": %d,\n' "$FAILURES"
    printf '  "score": %d,\n' "$score"
    printf '  "results": [\n'
    local i=0
    for result in "${RESULTS[@]}"; do
      if [[ $i -gt 0 ]]; then
        printf ',\n'
      fi
      printf '    %s' "$result"
      i=$((i + 1))
    done
    printf '\n  ]\n'
    printf '}\n'
    dot_log info "health_complete" "score=$score" "total=$TOTAL_CHECKS"
    dot_metric "health_score" "$score" "percent"
    return
  fi

  echo ""
  header "Summary"
  echo ""

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

  # Health score bar
  local bar_width=30
  local filled=$((score * bar_width / 100))
  local empty=$((bar_width - filled))
  local filled_bar="" empty_bar="" i

  for ((i = 0; i < filled; i++)); do
    filled_bar+="${_GL_BAR_FILL}"
  done
  for ((i = 0; i < empty; i++)); do
    empty_bar+="${_GL_BAR_EMPTY}"
  done

  if [[ "$use_ui" = "1" ]]; then
    local bar_color
    if [[ $score -ge 80 ]]; then
      bar_color=2
    elif [[ $score -ge 60 ]]; then
      bar_color=3
    else
      bar_color=1
    fi
    printf "  Health Score: [%s%s] %s%%\n\n" \
      "$(gum style --foreground "$bar_color" "$filled_bar")" \
      "$empty_bar" \
      "$score"
  else
    printf "  Health Score: ["
    if [[ $score -ge 80 ]]; then
      printf '%s' "${GREEN}"
    elif [[ $score -ge 60 ]]; then
      printf '%s' "${YELLOW}"
    else
      printf '%s' "${RED}"
    fi
    printf '%s' "$filled_bar"
    printf '%s' "${NC}"
    printf '%s' "$empty_bar"
    printf "] %s%%\n\n" "${score}"
  fi

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

  dot_log info "health_complete" "score=$score" "total=$TOTAL_CHECKS"
  dot_metric "health_score" "$score" "percent"
}

# Main
export DOT_COMMAND="health"
print_header
run_checks
if $APPLY_FIX; then
  if ! $JSON_OUTPUT; then
    header "Auto-Remediation"
    echo ""
  fi
  heal_script="$SCRIPT_DIR/../ops/heal.sh"
  if [[ -f "$heal_script" ]]; then
    if $FORCE_FIX; then
      bash "$heal_script" --force || true
    else
      bash "$heal_script" || true
    fi
  else
    if ! $JSON_OUTPUT; then
      printf '%b\n' "${YELLOW}⚠${NC} heal.sh not found, skipping auto-fix."
    fi
  fi
  reset_stats
  run_checks
fi
print_summary
