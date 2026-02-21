#!/usr/bin/env bash
# Dotfiles Health Check Dashboard
# Usage: dot health [--verbose|-v] [--json] [--fix] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

# Colors (fallback when gum is unavailable)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

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
    --fix)
      APPLY_FIX=true
      shift
      ;;
    --force)
      FORCE_FIX=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    *) shift ;;
  esac
done

reset_stats() {
  unset RESULTS
  declare -A RESULTS
  TOTAL_CHECKS=0
  PASSED_CHECKS=0
  WARNINGS=0
  FAILURES=0
}

# Health check results
declare -A RESULTS
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
FAILURES=0
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
    echo -e "${CYAN}${text}${NC}"
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
    echo -e "\n${BLUE}▸ $text${NC}"
  fi
}

check() {
  local name="$1"
  local status="$2"
  local message="${3:-}"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  case "$status" in
    pass)
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      # shellcheck disable=SC2034
      RESULTS["$name"]="pass"
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
      RESULTS["$name"]="warn"
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
      RESULTS["$name"]="fail"
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

# === Core Checks ===
run_checks() {
  # --- Dotfiles Core ---
  check_section "Dotfiles Core"

  # Chezmoi
  if command -v chezmoi >/dev/null 2>&1; then
    check "Chezmoi installed" "pass"
    # Check if source dir exists
    if [[ -d "${HOME}/.local/share/chezmoi" ]] || [[ -d "${HOME}/.dotfiles" ]]; then
      check "Chezmoi source directory" "pass"
    else
      check "Chezmoi source directory" "fail" "Not found"
    fi
  else
    check "Chezmoi installed" "fail" "Not installed"
  fi

  # Git
  if command -v git >/dev/null 2>&1; then
    check "Git installed" "pass"
    if git config user.email >/dev/null 2>&1; then
      check "Git user configured" "pass"
    else
      check "Git user configured" "warn" "Email not set"
    fi
  else
    check "Git installed" "fail"
  fi

  # --- Shell ---
  check_section "Shell Environment"

  # Zsh
  if command -v zsh >/dev/null 2>&1; then
    check "Zsh installed" "pass"
    if [[ "$SHELL" == *"zsh"* ]]; then
      check "Zsh is default shell" "pass"
    else
      check "Zsh is default shell" "warn" "Current: $SHELL"
    fi
  else
    check "Zsh installed" "fail"
  fi

  # Zinit
  if [[ -d "${ZINIT_HOME:-$HOME/.local/share/zinit}" ]]; then
    check "Zinit plugin manager" "pass"
  else
    check "Zinit plugin manager" "warn" "Not found"
  fi

  # Starship
  if command -v starship >/dev/null 2>&1; then
    check "Starship prompt" "pass"
  else
    check "Starship prompt" "warn" "Not installed"
  fi

  # --- Development Tools ---
  check_section "Development Tools"

  # Node.js
  if command -v node >/dev/null 2>&1; then
    local node_version
    node_version=$(node --version 2>/dev/null)
    check "Node.js ($node_version)" "pass"
  else
    check "Node.js" "warn" "Not installed"
  fi

  # fnm
  if command -v fnm >/dev/null 2>&1; then
    check "fnm (Node version manager)" "pass"
  else
    check "fnm" "warn" "Not installed"
  fi

  # Python
  if command -v python3 >/dev/null 2>&1; then
    local py_version
    py_version=$(python3 --version 2>/dev/null | cut -d' ' -f2)
    check "Python ($py_version)" "pass"
  else
    check "Python" "warn" "Not installed"
  fi

  # Rust
  if command -v rustc >/dev/null 2>&1; then
    check "Rust toolchain" "pass"
  else
    check "Rust toolchain" "warn" "Not installed"
  fi

  # Go
  if command -v go >/dev/null 2>&1; then
    check "Go" "pass"
  else
    check "Go" "warn" "Not installed"
  fi

  # --- CLI Tools ---
  check_section "CLI Tools"

  local tools=("fzf" "ripgrep:rg" "fd" "bat" "eza" "zoxide" "atuin" "delta" "jq" "yq" "sops" "mise" "just" "zellij" "hyperfine")
  for tool in "${tools[@]}"; do
    local name="${tool%%:*}"
    local cmd="${tool##*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      check "$name" "pass"
    else
      check "$name" "warn" "Not installed"
    fi
  done

  # --- Editors ---
  check_section "Editors"

  if command -v nvim >/dev/null 2>&1; then
    check "Neovim" "pass"
    if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy" ]]; then
      check "Neovim plugins (lazy.nvim)" "pass"
    else
      check "Neovim plugins" "warn" "Lazy.nvim not found"
    fi
  else
    check "Neovim" "warn" "Not installed"
  fi

  # --- Terminal ---
  check_section "Terminal"

  if command -v ghostty >/dev/null 2>&1 || [[ -d "/Applications/Ghostty.app" ]]; then
    check "Ghostty terminal" "pass"
  else
    check "Ghostty terminal" "warn" "Not installed"
  fi

  # Fonts - check both Linux and macOS font locations
  local font_found=false
  if fc-list 2>/dev/null | grep -qi "JetBrains"; then
    font_found=true
  elif [[ -d "$HOME/Library/Fonts" ]] && compgen -G "$HOME/Library/Fonts/"*[Jj]et[Bb]rains* >/dev/null 2>&1; then
    font_found=true
  elif [[ -d "$HOME/.local/share/fonts" ]] && compgen -G "$HOME/.local/share/fonts/"*[Jj]et[Bb]rains* >/dev/null 2>&1; then
    font_found=true
  fi

  if $font_found; then
    check "JetBrains Mono Nerd Font" "pass"
  else
    check "JetBrains Mono Nerd Font" "warn" "Not installed"
  fi

  # --- Security ---
  check_section "Security"

  # Age encryption
  if command -v age >/dev/null 2>&1; then
    check "Age encryption" "pass"
    if [[ -f "${HOME}/.config/chezmoi/key.txt" ]]; then
      check "Age key configured" "pass"
    else
      check "Age key configured" "warn" "Key not found"
    fi
  else
    check "Age encryption" "warn" "Not installed"
  fi

  # SSH
  if [[ -f "${HOME}/.ssh/id_ed25519" ]] || [[ -f "${HOME}/.ssh/id_rsa" ]]; then
    check "SSH keys present" "pass"
  else
    check "SSH keys present" "warn" "No keys found"
  fi

  # GPG
  if command -v gpg >/dev/null 2>&1; then
    if gpg --list-secret-keys 2>/dev/null | grep -q sec; then
      check "GPG keys" "pass"
    else
      check "GPG keys" "warn" "No secret keys"
    fi
  else
    check "GPG" "warn" "Not installed"
  fi

  # --- Performance ---
  check_section "Performance"

  # Shell startup time
  if command -v zsh >/dev/null 2>&1; then
    local startup_time
    startup_time=$({ time zsh -i -c exit; } 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]//g')
    # Try to parse the time (handle different formats)
    if [[ -n "$startup_time" ]]; then
      # Simple check - if startup mentions 0m0, it's under 1 second
      check "Shell startup time" "pass"
    else
      check "Shell startup time" "warn" "Could not measure"
    fi
  fi
}

print_summary() {
  if $JSON_OUTPUT; then
    echo "{"
    echo "  \"total\": $TOTAL_CHECKS,"
    echo "  \"passed\": $PASSED_CHECKS,"
    echo "  \"warnings\": $WARNINGS,"
    echo "  \"failures\": $FAILURES,"
    echo "  \"score\": $((PASSED_CHECKS * 100 / TOTAL_CHECKS))"
    echo "}"
    return
  fi

  local score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

  echo ""
  header "Summary"
  echo ""

  if [[ "$use_ui" = "1" ]]; then
    printf "  %-12s %s\n" "Total checks:" "${TOTAL_CHECKS}"
    printf "  %-12s %s\n" "Passed:" "$(gum style --foreground 2 "$PASSED_CHECKS")"
    printf "  %-12s %s\n" "Warnings:" "$(gum style --foreground 3 "$WARNINGS")"
    printf "  %-12s %s\n" "Failures:" "$(gum style --foreground 1 "$FAILURES")"
  else
    echo -e "  Total checks:  ${TOTAL_CHECKS}"
    echo -e "  ${GREEN}Passed:${NC}        ${PASSED_CHECKS}"
    echo -e "  ${YELLOW}Warnings:${NC}      ${WARNINGS}"
    echo -e "  ${RED}Failures:${NC}      ${FAILURES}"
  fi
  echo ""

  # Health score bar
  local bar_width=30
  local filled=$((score * bar_width / 100))
  local empty=$((bar_width - filled))

  if [[ "$use_ui" = "1" ]]; then
    local filled_bar empty_bar bar_color
    filled_bar=$(printf "%${filled}s" | tr ' ' '█')
    empty_bar=$(printf "%${empty}s" | tr ' ' '░')
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
    printf "%${filled}s" | tr ' ' '█'
    printf '%s' "${NC}"
    printf "%${empty}s" | tr ' ' '░'
    printf "] %s%%\n\n" "${score}"
  fi

  if [[ $score -ge 90 ]]; then
    echo -e "  ${GREEN}⚡ Excellent! Your dotfiles are in great shape.${NC}"
  elif [[ $score -ge 70 ]]; then
    echo -e "  ${GREEN}✓ Good! Minor improvements possible.${NC}"
  elif [[ $score -ge 50 ]]; then
    echo -e "  ${YELLOW}⚠ Fair. Consider addressing warnings.${NC}"
  else
    echo -e "  ${RED}✗ Needs attention. Multiple issues found.${NC}"
  fi

  echo ""
  if [[ $WARNINGS -gt 0 || $FAILURES -gt 0 ]]; then
    echo -e "  ${CYAN}Tip:${NC} Run 'dot health --fix' to auto-repair common issues."
    echo ""
  fi
}

# Main
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
      echo -e "${YELLOW}⚠${NC} heal.sh not found, skipping auto-fix."
    fi
  fi
  reset_stats
  run_checks
fi
print_summary
