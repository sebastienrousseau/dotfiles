#!/usr/bin/env bash
# Dotfiles CLI Utilities
# Shared functions for dot command modules

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ui.sh
source "$SCRIPT_DIR/ui.sh"

# Resolve the dotfiles source directory
resolve_source_dir() {
  if [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    echo "$CHEZMOI_SOURCE_DIR"
    return
  fi
  if [ -d "$HOME/.dotfiles" ]; then
    echo "$HOME/.dotfiles"
    return
  fi
  if [ -d "$HOME/.local/share/chezmoi" ]; then
    echo "$HOME/.local/share/chezmoi"
    return
  fi
  echo ""
}

# Generic dispatcher: resolve source dir, find script, exec it.
# Usage: run_script <relative-script-path> <not-found-label> [args...]
run_script() {
  local script_rel="$1"
  local label="$2"
  shift 2
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  if [ -f "$src_dir/$script_rel" ]; then
    exec bash "$src_dir/$script_rel" "$@"
  else
    echo "$label not found." >&2
    exit 1
  fi
}

# Require source directory or exit
require_source_dir() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  echo "$src_dir"
}

# Check if a command exists
has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Print error message and exit
die() {
  ui_err "$1" >&2
  exit "${2:-1}"
}

# Print warning message
warn() {
  ui_warn "$1" >&2
}

# Print info message
info() {
  ui_info "$1"
}

# Print the dot logo once per process for interactive sessions.
ui_logo_once() {
  local title="${1:-Dot}"
  ui_init
  if [[ "${DOTFILES_SHOW_LOGO:-1}" != "1" ]]; then
    return
  fi
  if [[ ! -t 1 ]]; then
    return
  fi
  if [[ "${DOTFILES_LOGO_PRINTED:-0}" = "1" ]]; then
    return
  fi
  ui_logo_dot "$title"
  DOTFILES_LOGO_PRINTED=1
  export DOTFILES_LOGO_PRINTED
}

dotfiles_version() {
  local src_dir version=""
  src_dir="$(resolve_source_dir)"

  if [[ -n "$src_dir" ]] && [[ -f "$src_dir/package.json" ]]; then
    version="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$src_dir/package.json" | head -1)"
  fi

  if [[ -z "$version" ]] && [[ -n "${DOTFILES_VERSION:-}" ]]; then
    version="$DOTFILES_VERSION"
  fi

  if [[ -z "$version" ]]; then
    version="unknown"
  fi

  printf "%s\n" "$version"
}

dot_command_summary() {
  case "${1:-}" in
    apply | sync)
      echo "Apply dotfiles changes to this machine."
      ;;
    update)
      echo "Pull latest dotfiles changes and apply them."
      ;;
    add)
      echo "Add a file into chezmoi source management."
      ;;
    diff)
      echo "Show pending managed-file differences."
      ;;
    status)
      echo "Show current configuration drift status."
      ;;
    remove)
      echo "Safely remove a managed file from source."
      ;;
    cd)
      echo "Print the dotfiles source directory path."
      ;;
    edit)
      echo "Open dotfiles source in your editor."
      ;;
    doctor)
      echo "Run system and dotfiles diagnostics."
      ;;
    heal)
      echo "Attempt automatic repair of common issues."
      ;;
    health | health-check)
      echo "Run a full health dashboard."
      ;;
    security-score)
      echo "Calculate and print security posture score."
      ;;
    rollback)
      echo "Rollback dotfiles state to a prior point."
      ;;
    restore)
      echo "Restore files from backup or git reference."
      ;;
    drift)
      echo "Display detailed drift information."
      ;;
    history)
      echo "Analyze shell command history."
      ;;
    benchmark)
      echo "Measure shell startup performance."
      ;;
    tools)
      echo "Browse or install toolchain components."
      ;;
    new)
      echo "Create a new project from templates."
      ;;
    packages)
      echo "List package managers and package stats."
      ;;
    log-rotate)
      echo "Rotate dotfiles local log files."
      ;;
    theme)
      echo "Switch terminal appearance theme."
      ;;
    wallpaper)
      echo "Apply or sync wallpapers."
      ;;
    fonts)
      echo "Install Nerd Fonts for terminal tooling."
      ;;
    tune)
      echo "Apply OS-level tuning defaults."
      ;;
    secrets-init)
      echo "Initialize age key for encrypted secrets."
      ;;
    secrets)
      echo "Edit encrypted dotfiles secrets."
      ;;
    secrets-create)
      echo "Create a new encrypted secrets file."
      ;;
    ssh-key)
      echo "Encrypt an SSH key using age."
      ;;
    backup)
      echo "Create a compressed backup."
      ;;
    encrypt-check)
      echo "Check disk encryption status."
      ;;
    firewall)
      echo "Apply firewall hardening settings."
      ;;
    telemetry)
      echo "Disable telemetry where supported."
      ;;
    dns-doh)
      echo "Enable DNS-over-HTTPS."
      ;;
    lock-screen)
      echo "Harden lock-screen idle policy."
      ;;
    usb-safety)
      echo "Disable risky removable-media automount."
      ;;
    upgrade)
      echo "Upgrade dotfiles and related toolchains."
      ;;
    docs)
      echo "Show dotfiles documentation."
      ;;
    learn)
      echo "Start the interactive onboarding tour."
      ;;
    keys)
      echo "Show keybindings catalog."
      ;;
    sandbox)
      echo "Start isolated sandbox environment."
      ;;
    mcp)
      echo "Run MCP configuration diagnostics."
      ;;
    help | --help | -h)
      echo "Show command usage and reference."
      ;;
    --version | -v | version)
      echo "Show dotfiles and environment versions."
      ;;
    *)
      echo "Run a dotfiles command."
      ;;
  esac
}

dot_ui_command_banner() {
  local section="${1:-Dot}"
  local cmd="${2:-}"
  local version summary

  ui_logo_once "Dot • $section"

  if [[ "${DOTFILES_SHOW_LOGO:-1}" != "1" ]] || [[ ! -t 1 ]]; then
    return
  fi

  version="$(dotfiles_version)"
  summary="$(dot_command_summary "$cmd")"

  ui_key_value "Version" "v${version}"
  if [[ -n "$cmd" ]]; then
    ui_key_value "Command" "dot ${cmd}"
  fi
  ui_key_value "Summary" "$summary"
  printf "\n"
}
