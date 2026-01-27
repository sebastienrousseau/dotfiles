#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2034
# =============================================================================
# Dotfiles Health Check Script
# Verifies that dotfiles installation is functioning correctly
# Usage: ./scripts/ops/health-check.sh [--verbose] [--json]
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CHEZMOI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
DOTFILES_SOURCE="${HOME}/.dotfiles"

# Output control
VERBOSE=0
JSON_OUTPUT=0
EXIT_CODE=0

# Colors (disabled if not a terminal or JSON mode)
if [[ -t 1 ]] && [[ "$JSON_OUTPUT" != "1" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Results collection for JSON
declare -a RESULTS=()

log_info() { [[ "$VERBOSE" == "1" ]] && echo -e "${BLUE}[INFO]${NC} $*" || true; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() {
  echo -e "${RED}[FAIL]${NC} $*"
  EXIT_CODE=1
}
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

add_result() {
  local name="$1" status="$2" message="${3:-}"
  RESULTS+=("{\"check\": \"$name\", \"status\": \"$status\", \"message\": \"$message\"}")
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    -j | --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h | --help)
      echo "Usage: $(basename "$0") [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -v, --verbose    Show detailed output"
      echo "  -j, --json       Output results as JSON"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# =============================================================================
# Health Check Functions
# =============================================================================

check_chezmoi_installed() {
  log_info "Checking chezmoi installation..."
  if command -v chezmoi >/dev/null 2>&1; then
    local version
    version=$(chezmoi --version 2>/dev/null | head -1)
    log_pass "chezmoi installed: $version"
    add_result "chezmoi_installed" "pass" "$version"
    return 0
  else
    log_fail "chezmoi not installed or not in PATH"
    add_result "chezmoi_installed" "fail" "not found"
    return 1
  fi
}

check_dotfiles_source() {
  log_info "Checking dotfiles source directory..."
  if [[ -d "$DOTFILES_SOURCE" ]]; then
    if [[ -d "$DOTFILES_SOURCE/.git" ]]; then
      log_pass "Source directory exists with git: $DOTFILES_SOURCE"
      add_result "dotfiles_source" "pass" "$DOTFILES_SOURCE"
      return 0
    else
      log_warn "Source directory exists but no .git: $DOTFILES_SOURCE"
      add_result "dotfiles_source" "warn" "no git"
      return 0
    fi
  else
    log_fail "Source directory not found: $DOTFILES_SOURCE"
    add_result "dotfiles_source" "fail" "not found"
    return 1
  fi
}

check_chezmoi_config() {
  log_info "Checking chezmoi configuration..."
  local config_file="$CHEZMOI_CONFIG_DIR/chezmoi.toml"
  if [[ -f "$config_file" ]]; then
    log_pass "chezmoi config exists: $config_file"
    add_result "chezmoi_config" "pass" "$config_file"
    return 0
  else
    log_warn "chezmoi config not found (using defaults)"
    add_result "chezmoi_config" "warn" "using defaults"
    return 0
  fi
}

check_critical_files() {
  log_info "Checking critical dotfiles..."
  local critical_files=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.profile"
  )
  local missing=0

  for file in "${critical_files[@]}"; do
    if [[ -f "$file" ]] || [[ -L "$file" ]]; then
      log_info "  Found: $file"
    else
      log_warn "  Missing: $file"
      ((missing++))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    log_pass "All critical shell configs present"
    add_result "critical_files" "pass" "all present"
    return 0
  else
    log_warn "$missing critical file(s) missing"
    add_result "critical_files" "warn" "$missing missing"
    return 0
  fi
}

check_config_directories() {
  log_info "Checking config directories..."
  local config_dirs=(
    "$HOME/.config/shell"
    "$HOME/.config/nvim"
    "$HOME/.config/git"
  )
  local found=0 total=${#config_dirs[@]}

  for dir in "${config_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      log_info "  Found: $dir"
      ((found++))
    else
      log_info "  Missing: $dir"
    fi
  done

  if [[ $found -eq $total ]]; then
    log_pass "All expected config directories present"
    add_result "config_directories" "pass" "$found/$total"
    return 0
  elif [[ $found -gt 0 ]]; then
    log_warn "$found of $total config directories present"
    add_result "config_directories" "warn" "$found/$total"
    return 0
  else
    log_fail "No config directories found"
    add_result "config_directories" "fail" "0/$total"
    return 1
  fi
}

check_shell_startup_performance() {
  log_info "Checking shell startup performance..."
  local threshold_ms=500
  local shells=("bash" "zsh")
  local slow_shells=0

  for shell in "${shells[@]}"; do
    if command -v "$shell" >/dev/null 2>&1; then
      local start_ms end_ms duration_ms
      start_ms=$(($(date +%s%N) / 1000000))
      "$shell" -i -c 'exit' 2>/dev/null || true
      end_ms=$(($(date +%s%N) / 1000000))
      duration_ms=$((end_ms - start_ms))

      if [[ $duration_ms -gt $threshold_ms ]]; then
        log_warn "$shell startup: ${duration_ms}ms (threshold: ${threshold_ms}ms)"
        ((slow_shells++))
      else
        log_info "  $shell startup: ${duration_ms}ms"
      fi
    fi
  done

  if [[ $slow_shells -eq 0 ]]; then
    log_pass "Shell startup performance OK"
    add_result "shell_performance" "pass" "under ${threshold_ms}ms"
    return 0
  else
    log_warn "$slow_shells shell(s) exceed startup threshold"
    add_result "shell_performance" "warn" "slow startup"
    return 0
  fi
}

check_chezmoi_status() {
  log_info "Checking chezmoi managed files status..."
  if ! command -v chezmoi >/dev/null 2>&1; then
    log_warn "Skipping chezmoi status (not installed)"
    add_result "chezmoi_status" "skip" "not installed"
    return 0
  fi

  local status_output
  status_output=$(chezmoi status 2>/dev/null || echo "")

  if [[ -z "$status_output" ]]; then
    log_pass "All managed files in sync"
    add_result "chezmoi_status" "pass" "in sync"
    return 0
  else
    local changes
    changes=$(echo "$status_output" | wc -l | tr -d ' ')
    log_warn "$changes file(s) out of sync with source"
    add_result "chezmoi_status" "warn" "$changes out of sync"
    return 0
  fi
}

check_git_status() {
  log_info "Checking git repository status..."
  if [[ ! -d "$DOTFILES_SOURCE/.git" ]]; then
    log_warn "Not a git repository"
    add_result "git_status" "skip" "not a repo"
    return 0
  fi

  local git_status
  git_status=$(cd "$DOTFILES_SOURCE" && git status --porcelain 2>/dev/null || echo "")

  if [[ -z "$git_status" ]]; then
    log_pass "Git working tree clean"
    add_result "git_status" "pass" "clean"
    return 0
  else
    local changes
    changes=$(echo "$git_status" | wc -l | tr -d ' ')
    log_warn "Git has $changes uncommitted change(s)"
    add_result "git_status" "warn" "$changes changes"
    return 0
  fi
}

check_dependencies() {
  log_info "Checking recommended dependencies..."
  local deps=(git curl zsh)
  local optional_deps=(ripgrep fd bat fzf eza jq)
  local missing_required=0
  local missing_optional=0

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      log_fail "Required dependency missing: $dep"
      ((missing_required++))
    fi
  done

  for dep in "${optional_deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      log_info "  Optional dependency missing: $dep"
      ((missing_optional++))
    fi
  done

  if [[ $missing_required -eq 0 ]]; then
    log_pass "All required dependencies present"
    add_result "dependencies" "pass" "optional: $missing_optional missing"
    return 0
  else
    log_fail "$missing_required required dependency(s) missing"
    add_result "dependencies" "fail" "$missing_required missing"
    return 1
  fi
}

check_symlinks_valid() {
  log_info "Checking symlink integrity..."
  local broken=0

  while IFS= read -r -d '' link; do
    if [[ ! -e "$link" ]]; then
      log_warn "Broken symlink: $link"
      ((broken++))
    fi
  done < <(find "$HOME" -maxdepth 2 -type l -print0 2>/dev/null)

  if [[ $broken -eq 0 ]]; then
    log_pass "No broken symlinks in home directory"
    add_result "symlinks" "pass" "all valid"
    return 0
  else
    log_warn "$broken broken symlink(s) found"
    add_result "symlinks" "warn" "$broken broken"
    return 0
  fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
  if [[ "$JSON_OUTPUT" != "1" ]]; then
    echo ""
    echo "=========================================="
    echo "     Dotfiles Health Check"
    echo "=========================================="
    echo ""
  fi

  # Run all checks
  check_chezmoi_installed || true
  check_dotfiles_source || true
  check_chezmoi_config || true
  check_critical_files || true
  check_config_directories || true
  check_dependencies || true
  check_chezmoi_status || true
  check_git_status || true
  check_symlinks_valid || true
  check_shell_startup_performance || true

  if [[ "$JSON_OUTPUT" == "1" ]]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"exit_code\": $EXIT_CODE,"
    echo "  \"results\": ["
    local first=1
    for result in "${RESULTS[@]}"; do
      [[ $first -eq 0 ]] && echo ","
      echo -n "    $result"
      first=0
    done
    echo ""
    echo "  ]"
    echo "}"
  else
    echo ""
    echo "=========================================="
    if [[ $EXIT_CODE -eq 0 ]]; then
      echo -e "${GREEN}${BOLD}Health Check: PASSED${NC}"
    else
      echo -e "${RED}${BOLD}Health Check: FAILED${NC}"
    fi
    echo "=========================================="
  fi

  exit $EXIT_CODE
}

main "$@"
