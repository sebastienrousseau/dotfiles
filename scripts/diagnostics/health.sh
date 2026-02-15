#!/usr/bin/env bash
# Dotfiles Health Check Dashboard
# Usage: dot health [--verbose|-v] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

# Parse arguments
export VERBOSE=true
JSON_OUTPUT=false
QUIET=false
AUTO_FIX=false
PROGRESS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --progress)
      PROGRESS=true
      shift
      ;;
    --quiet | -q)
      QUIET=true
      shift
      ;;
    --fix)
      AUTO_FIX=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    *) shift ;;
  esac
done

# Health check results
declare -A RESULTS
declare -A RESULT_MSG
declare -A RESULT_FIX
RESULT_ORDER=()
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
FAILURES=0
TOOLS=("fzf" "ripgrep:rg" "fd" "bat" "eza" "zoxide" "atuin" "delta" "jq" "yq" "sops" "mise" "just" "zellij" "hyperfine")

EXPECTED_CHECKS=$((4 + 4 + 4 + ${#TOOLS[@]} + 2 + 2 + 4 + 1))

CURRENT_SECTION=""
declare -A SECTION_TOTAL
declare -A SECTION_PASS
declare -A SECTION_WARN
declare -A SECTION_FAIL

section_start() {
  local name="$1"
  CURRENT_SECTION="$name"
  : "$name"
}

section_end() {
  local name="$1"
  : "$name"
}

check() {
  local name="$1"
  local status="$2"
  local message="${3:-}"
  local fix_id="${4:-}"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  SECTION_TOTAL["$CURRENT_SECTION"]=$((${SECTION_TOTAL[$CURRENT_SECTION]:-0} + 1))

  case "$status" in
    pass)
      PASSED_CHECKS=$((PASSED_CHECKS + 1))
      RESULTS["$name"]="pass"
      SECTION_PASS["$CURRENT_SECTION"]=$((${SECTION_PASS[$CURRENT_SECTION]:-0} + 1))
      ;;
    warn)
      WARNINGS=$((WARNINGS + 1))
      RESULTS["$name"]="warn"
      SECTION_WARN["$CURRENT_SECTION"]=$((${SECTION_WARN[$CURRENT_SECTION]:-0} + 1))
      ;;
    fail)
      FAILURES=$((FAILURES + 1))
      RESULTS["$name"]="fail"
      SECTION_FAIL["$CURRENT_SECTION"]=$((${SECTION_FAIL[$CURRENT_SECTION]:-0} + 1))
      ;;
  esac
  RESULT_MSG["$name"]="$message"
  RESULT_ORDER+=("$name")
  if [[ -n "$fix_id" ]]; then
    RESULT_FIX["$name"]="$fix_id"
  fi

  if ! $JSON_OUTPUT; then
    local detail=""
    if [[ -n "$message" ]]; then
      detail=" - $message"
    fi
    if $PROGRESS; then
      ui_progress_line "$status" "$name" "$detail"
      ui_progress_advance "Checking $name"
    else
      if $VERBOSE; then
        case "$status" in
          pass) ui_success "$name" ;;
          warn) ui_warn "$name" "$detail" ;;
          fail) ui_error "$name" "$detail" ;;
        esac
      else
        case "$status" in
          warn) ui_warn "$name" "$detail" ;;
          fail) ui_error "$name" "$detail" ;;
        esac
      fi
    fi
  fi
}

# === Core Checks ===
run_checks() {
  # --- Dotfiles Core ---
  section_start "Dotfiles Core"

  # Chezmoi
  if command -v chezmoi >/dev/null 2>&1; then
    check "Chezmoi installed" "pass"
  else
    check "Chezmoi installed" "fail" "Not installed"
  fi
  if [[ -d "${HOME}/.local/share/chezmoi" ]] || [[ -d "${HOME}/.dotfiles" ]]; then
    check "Chezmoi source directory" "pass"
  else
    check "Chezmoi source directory" "fail" "Not found"
  fi

  # Git
  if command -v git >/dev/null 2>&1; then
    check "Git installed" "pass"
    if git config user.email >/dev/null 2>&1; then
      check "Git user configured" "pass"
    else
      check "Git user configured" "warn" "Email not set" "fix_git_identity"
    fi
  else
    check "Git installed" "fail" "Not installed"
    check "Git user configured" "fail" "Git not installed"
  fi
  section_end "Dotfiles Core"

  # --- Shell ---
  section_start "Shell Environment"

  # Zsh
  if command -v zsh >/dev/null 2>&1; then
    check "Zsh installed" "pass"
    if [[ "$SHELL" == *"zsh"* ]]; then
      check "Zsh is default shell" "pass"
    else
      check "Zsh is default shell" "warn" "Current: $SHELL" "fix_zsh_default"
    fi
  else
    check "Zsh installed" "fail" "Not installed"
    check "Zsh is default shell" "fail" "Zsh not installed"
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
  section_end "Shell Environment"

  # --- Development Tools ---
  section_start "Development Tools"

  # Node.js
  if command -v node >/dev/null 2>&1; then
    local node_version
    node_version=$(node --version 2>/dev/null)
    check "Node.js ($node_version)" "pass"
  else
    check "Node.js" "warn" "Not installed"
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
  section_end "Development Tools"

  # --- CLI Tools ---
  section_start "CLI Tools"

  for tool in "${TOOLS[@]}"; do
    local name="${tool%%:*}"
    local cmd="${tool##*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      check "$name" "pass"
    else
      check "$name" "warn" "Not installed"
    fi
  done
  section_end "CLI Tools"

  # --- Editors ---
  section_start "Editors"

  if command -v nvim >/dev/null 2>&1; then
    check "Neovim" "pass"
    if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy" ]]; then
      check "Neovim plugins (lazy.nvim)" "pass"
    else
      check "Neovim plugins" "warn" "Lazy.nvim not found"
    fi
  else
    check "Neovim" "warn" "Not installed"
    check "Neovim plugins" "warn" "Neovim not installed"
  fi
  section_end "Editors"

  # --- Terminal ---
  section_start "Terminal"

  if command -v ghostty >/dev/null 2>&1 || [[ -d "/Applications/Ghostty.app" ]]; then
    check "Ghostty terminal" "pass"
  else
    check "Ghostty terminal" "warn" "Not installed"
  fi

  if fc-list 2>/dev/null | grep -qi "JetBrains"; then
    check "JetBrains Mono Nerd Font" "pass"
  else
    check "JetBrains Mono Nerd Font" "warn" "Not installed" "fix_jb_font"
  fi
  section_end "Terminal"

  # --- Security ---
  section_start "Security"

  if command -v age >/dev/null 2>&1; then
    check "Age encryption" "pass"
  else
    check "Age encryption" "warn" "Not installed"
  fi
  if [[ -f "${HOME}/.config/chezmoi/key.txt" ]]; then
    check "Age key configured" "pass"
  else
    check "Age key configured" "warn" "Key not found"
  fi

  if [[ -f "${HOME}/.ssh/id_ed25519" ]] || [[ -f "${HOME}/.ssh/id_rsa" ]]; then
    check "SSH keys present" "pass"
  else
    check "SSH keys present" "warn" "No keys found"
  fi

  if command -v gpg >/dev/null 2>&1; then
    if gpg --list-secret-keys 2>/dev/null | grep -q sec; then
      check "GPG keys" "pass"
    else
      check "GPG keys" "warn" "No secret keys"
    fi
  else
    check "GPG keys" "warn" "GPG not installed"
  fi
  section_end "Security"

  # --- Performance ---
  section_start "Performance"

  if command -v zsh >/dev/null 2>&1; then
    local startup_time
    startup_time=$({ time zsh -i -c exit; } 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]//g')
    if [[ -n "$startup_time" ]]; then
      check "Shell startup time" "pass"
    else
      check "Shell startup time" "warn" "Could not measure"
    fi
  else
    check "Shell startup time" "warn" "Zsh not installed"
  fi
  section_end "Performance"
}

fix_git_identity() {
  if ! command -v git >/dev/null 2>&1; then
    ui_warn "Git not installed; cannot set identity."
    return 1
  fi
  local name email
  read -r -p "Git name: " name
  read -r -p "Git email: " email
  if [[ -z "$name" || -z "$email" ]]; then
    ui_warn "Skipped. Name and email are required."
    return 1
  fi
  git config --global user.name "$name"
  git config --global user.email "$email"
  ui_success "Configured git identity."
}

fix_zsh_default() {
  if ! command -v zsh >/dev/null 2>&1; then
    ui_warn "Zsh not installed."
    return 1
  fi
  local zsh_path
  zsh_path=$(command -v zsh)
  if ui_ask "Change default shell to zsh ($zsh_path)?"; then
    chsh -s "$zsh_path" && ui_success "Default shell updated."
  else
    ui_info "Skipped changing default shell."
  fi
}

fix_jb_font() {
  ui_info "Install JetBrains Mono Nerd Font:"
  ui_bullet "macOS: brew install --cask font-jetbrains-mono-nerd-font"
  ui_bullet "Linux: https://www.nerdfonts.com/font-downloads"
}

apply_fixes() {
  local fixable=0
  local name
  for name in "${!RESULTS[@]}"; do
    local status="${RESULTS[$name]}"
    local fix_id="${RESULT_FIX[$name]:-}"
    if [[ "$status" != "pass" && -n "$fix_id" ]]; then
      fixable=$((fixable + 1))
    fi
  done

  if (( fixable == 0 )); then
    ui_info "No automatic fixes available."
    return
  fi

  ui_info "Fixes available for ${fixable} item(s)."
  for name in "${!RESULTS[@]}"; do
    local status="${RESULTS[$name]}"
    local fix_id="${RESULT_FIX[$name]:-}"
    if [[ "$status" != "pass" && -n "$fix_id" ]]; then
      ui_info "Fixing: $name"
      "$fix_id"
    fi
  done
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

  ui_section "Summary"
  ui_key_value "Total checks" "$TOTAL_CHECKS"
  ui_key_value "Passed" "$PASSED_CHECKS"
  ui_key_value "Warnings" "$WARNINGS"
  ui_key_value "Failures" "$FAILURES"
  printf "\n"
  local bar
  bar=$(ui_progress_bar "$score" 24)
  if [[ $score -ge 90 ]]; then
    ui_key_value "Health Score" "${GREEN}${bar}${NORMAL} ${score}%"
  elif [[ $score -ge 70 ]]; then
    ui_key_value "Health Score" "${YELLOW}${bar}${NORMAL} ${score}%"
  else
    ui_key_value "Health Score" "${RED}${bar}${NORMAL} ${score}%"
  fi

  printf "\n"
  if [[ $score -ge 90 ]]; then
    ui_info "Excellent! Your dotfiles are in great shape."
  elif [[ $score -ge 70 ]]; then
    ui_info "Good! Minor improvements possible."
  elif [[ $score -ge 50 ]]; then
    ui_warn "Fair. Consider addressing warnings."
  else
    ui_error "Needs attention. Multiple issues found."
  fi
  printf "\n"

}


# Main
ui_logo_dot "Dot Health • Diagnostics"
if ! $JSON_OUTPUT; then
  if ! $QUIET; then
    ui_info "Running ${EXPECTED_CHECKS} checks. This can take a few seconds."
  fi
  if $PROGRESS; then
    ui_progress_start "$EXPECTED_CHECKS" "Checking..." "$QUIET"
  fi
fi
run_checks
if ! $JSON_OUTPUT; then
  if $PROGRESS; then
    ui_progress_end
  fi
fi
print_summary

if ! $JSON_OUTPUT; then
  if (( WARNINGS > 0 || FAILURES > 0 )); then
    if $AUTO_FIX; then
      apply_fixes
    else
      if ui_ask "Fix warnings now?"; then
        apply_fixes
      fi
    fi
  fi
fi
