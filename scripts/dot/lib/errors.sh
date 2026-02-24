#!/usr/bin/env bash
## Dotfiles CLI Error Handling Library
##
## Provides consistent, actionable error messages with suggested fixes.
##
## # Usage
## source "$SCRIPT_DIR/lib/errors.sh"
## err_missing_command "nvim" "dot tools install nvim"
## err_file_not_found "/path/to/file"

# shellcheck source=ui.sh
[[ -z "${UI_INITED:-}" ]] && source "${BASH_SOURCE[0]%/*}/ui.sh"

# =============================================================================
# Core Error Functions
# =============================================================================

# Generic error with optional suggestion
# Usage: err "message" ["suggestion"]
err() {
  local msg="$1"
  local suggestion="${2:-}"

  ui_init
  ui_err "Error" "$msg"

  if [[ -n "$suggestion" ]]; then
    echo ""
    if [[ "$UI_COLOR" = "1" ]]; then
      printf "  %sSuggestion:%s %s\n" "$CYAN" "$NORMAL" "$suggestion"
    else
      printf "  Suggestion: %s\n" "$suggestion"
    fi
  fi
}

# Fatal error - prints message and exits
# Usage: die "message" ["suggestion"] [exit_code]
die() {
  local msg="$1"
  local suggestion="${2:-}"
  local code="${3:-1}"

  err "$msg" "$suggestion"
  exit "$code"
}

# =============================================================================
# Specific Error Types
# =============================================================================

# Command not found error
err_missing_command() {
  local cmd="$1"
  local install_hint="${2:-}"

  local suggestion=""
  if [[ -n "$install_hint" ]]; then
    suggestion="Run: $install_hint"
  else
    # Try to suggest install method
    case "$cmd" in
      nvim|neovim)
        suggestion="Run: brew install neovim (macOS) or apt install neovim (Linux)"
        ;;
      chezmoi)
        suggestion="Run: brew install chezmoi or sh -c \"\$(curl -fsLS get.chezmoi.io)\""
        ;;
      gum)
        suggestion="Run: brew install gum or go install github.com/charmbracelet/gum@latest"
        ;;
      starship)
        suggestion="Run: brew install starship or curl -sS https://starship.rs/install.sh | sh"
        ;;
      fzf)
        suggestion="Run: brew install fzf or apt install fzf"
        ;;
      *)
        suggestion="Install '$cmd' using your package manager"
        ;;
    esac
  fi

  err "Command not found: $cmd" "$suggestion"
}

# File not found error
err_file_not_found() {
  local path="$1"
  local suggestion="${2:-}"

  if [[ -z "$suggestion" ]]; then
    local dir="${path%/*}"
    if [[ ! -d "$dir" ]]; then
      suggestion="Directory does not exist: $dir"
    else
      suggestion="Check the path and try again"
    fi
  fi

  err "File not found: $path" "$suggestion"
}

# Permission denied error
err_permission_denied() {
  local path="$1"
  local operation="${2:-access}"

  local suggestion="Check file permissions with: ls -la $path"
  if [[ "$operation" == "write" ]]; then
    suggestion="Run: chmod u+w $path or check ownership"
  elif [[ "$operation" == "execute" ]]; then
    suggestion="Run: chmod +x $path"
  fi

  err "Permission denied: cannot $operation $path" "$suggestion"
}

# Configuration error
err_config() {
  local config_file="$1"
  local issue="$2"
  local suggestion="${3:-}"

  if [[ -z "$suggestion" ]]; then
    suggestion="Edit the config: \$EDITOR $config_file"
  fi

  err "Configuration error in $config_file: $issue" "$suggestion"
}

# Network error
err_network() {
  local url="$1"
  local suggestion="${2:-Check your internet connection and try again}"

  err "Network error: could not reach $url" "$suggestion"
}

# Git error
err_git() {
  local operation="$1"
  local details="${2:-}"
  local suggestion="${3:-}"

  local msg="Git $operation failed"
  [[ -n "$details" ]] && msg="$msg: $details"

  if [[ -z "$suggestion" ]]; then
    case "$operation" in
      push)
        suggestion="Try: git pull --rebase && git push"
        ;;
      pull)
        suggestion="Check for uncommitted changes: git status"
        ;;
      clone)
        suggestion="Verify the repository URL and your access rights"
        ;;
      commit)
        suggestion="Check if there are staged changes: git status"
        ;;
      *)
        suggestion="Run: git status to diagnose"
        ;;
    esac
  fi

  err "$msg" "$suggestion"
}

# Dependency error
err_dependency() {
  local dep="$1"
  local required_by="${2:-}"
  local suggestion="${3:-}"

  local msg="Missing dependency: $dep"
  [[ -n "$required_by" ]] && msg="$msg (required by $required_by)"

  if [[ -z "$suggestion" ]]; then
    suggestion="Run: dot doctor to check all dependencies"
  fi

  err "$msg" "$suggestion"
}

# Invalid argument error
err_invalid_arg() {
  local arg="$1"
  local expected="${2:-}"
  local suggestion="${3:-}"

  local msg="Invalid argument: $arg"
  [[ -n "$expected" ]] && msg="$msg (expected: $expected)"

  if [[ -z "$suggestion" ]]; then
    suggestion="Run with --help for usage information"
  fi

  err "$msg" "$suggestion"
}

# =============================================================================
# Warning Functions
# =============================================================================

# Non-fatal warning
warn() {
  local msg="$1"
  local hint="${2:-}"

  ui_init
  ui_warn "Warning" "$msg"

  if [[ -n "$hint" ]]; then
    if [[ "$UI_COLOR" = "1" ]]; then
      printf "  %sHint:%s %s\n" "$GRAY" "$NORMAL" "$hint"
    else
      printf "  Hint: %s\n" "$hint"
    fi
  fi
}

# Deprecation warning
warn_deprecated() {
  local old="$1"
  local new="$2"

  warn "'$old' is deprecated" "Use '$new' instead"
}

# =============================================================================
# Diagnostic Helpers
# =============================================================================

# Print system info for debugging
print_debug_info() {
  ui_section "Debug Information"
  echo ""
  ui_kv "OS" "$(uname -s) $(uname -r)"
  ui_kv "Shell" "$SHELL ($BASH_VERSION${ZSH_VERSION:+$ZSH_VERSION})"
  ui_kv "User" "$USER"
  ui_kv "Home" "$HOME"
  ui_kv "PWD" "$PWD"
  ui_kv "PATH" "${PATH:0:60}..."
  echo ""
  ui_kv "DOTFILES_PROFILE" "${DOTFILES_PROFILE:-<not set>}"
  ui_kv "DOTFILES_FAST" "${DOTFILES_FAST:-0}"
  echo ""
}

# Suggest running doctor
suggest_doctor() {
  echo ""
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "  %sRun %sdot doctor%s to diagnose system issues.%s\n" \
      "$GRAY" "$CYAN" "$GRAY" "$NORMAL"
  else
    printf "  Run 'dot doctor' to diagnose system issues.\n"
  fi
}
