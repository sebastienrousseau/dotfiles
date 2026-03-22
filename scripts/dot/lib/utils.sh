#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI Utilities
# Shared functions for dot command modules

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ui.sh
source "$SCRIPT_DIR/ui.sh"
# shellcheck source=platform.sh
source "$SCRIPT_DIR/platform.sh"

_DOT_SOURCE_DIR_CACHE=""

## resolve_source_dir — Locate the dotfiles source tree.
## Checks (in order): relative to this script, $CHEZMOI_SOURCE_DIR,
## ~/.dotfiles, ~/.local/share/chezmoi. Caches the result for the process.
## Prints the absolute path (or empty string if not found). Exit: always 0.
resolve_source_dir() {
  if [[ -n "${_DOT_SOURCE_DIR_CACHE:-}" ]] && [[ -d "$_DOT_SOURCE_DIR_CACHE" ]]; then
    printf "%s\n" "$_DOT_SOURCE_DIR_CACHE"
    return
  fi

  local dir=""
  local repo_candidate=""

  if repo_candidate="$(cd "$SCRIPT_DIR/../../.." && pwd 2>/dev/null)"; then
    :
  else
    repo_candidate=""
  fi
  if [[ -n "$repo_candidate" && -f "$repo_candidate/scripts/dot/lib/ui.sh" ]]; then
    dir="$repo_candidate"
  elif [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    dir="$CHEZMOI_SOURCE_DIR"
  elif [ -d "$HOME/.dotfiles" ]; then
    dir="$HOME/.dotfiles"
  elif [ -d "$HOME/.local/share/chezmoi" ]; then
    dir="$HOME/.local/share/chezmoi"
  fi

  if [ -n "$dir" ]; then
    # Resolve symlinks for consistent path handling
    if command -v realpath >/dev/null 2>&1; then
      dir="$(realpath "$dir")"
    elif command -v readlink >/dev/null 2>&1; then
      dir="$(readlink -f "$dir" 2>/dev/null || echo "$dir")"
    fi
    _DOT_SOURCE_DIR_CACHE="$dir"
    printf "%s\n" "$dir"
  else
    printf "%s\n" ""
  fi
}

## run_script — Resolve source dir, find a script, exec it (never returns).
## Usage: run_script <relative-script-path> <not-found-label> [args...]
## Exit: 1 if source dir or script not found; otherwise execs into the script.
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

## require_source_dir — Print source dir path or exit 1 if not found.
require_source_dir() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  echo "$src_dir"
}

## has_command <name> — Return 0 if <name> is on PATH, 1 otherwise.
has_command() {
  command -v "$1" >/dev/null 2>&1
}

## validate_name <name> [label] — Die if name contains unsafe characters.
## Allowed: [a-zA-Z0-9._-]. This prevents shell injection when names appear
## in paths or eval contexts. Exit: 0 if valid, calls die() if invalid.
validate_name() {
  local name="$1" label="${2:-name}"
  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    die "Invalid $label: $name (only alphanumeric, dash, underscore, dot allowed)"
  fi
}

## validate_xdg_path <var_name> <path> — Warn and return 1 if path is not absolute.
validate_xdg_path() {
  local var_name="$1" path="$2"
  if [[ -n "$path" ]] && [[ "$path" != /* ]]; then
    ui_warn "$var_name" "Not an absolute path: $path (ignoring, using default)"
    return 1
  fi
  return 0
}

## die <message> [code] — Print error to stderr and exit (default code 1).
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
  ui_product_banner "$title"
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
      echo "Apply dotfiles changes (sync is an alias for apply)."
      ;;
    update)
      echo "Pull latest changes from remote, then apply."
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
      echo "Deep audit: tools, paths, portability, AI analysis."
      ;;
    heal)
      echo "Auto-repair broken symlinks, missing tools, and drift."
      ;;
    health | health-check)
      echo "Dashboard with health score, checks, and auto-fix (--fix)."
      ;;
    security-score)
      echo "Calculate and print security posture score."
      ;;
    scorecard)
      echo "Show unified health, security, and performance scorecard."
      ;;
    perf)
      echo "Profile shell startup performance (3-run average)."
      ;;
    conflicts)
      echo "Report alias and command conflicts."
      ;;
    locks)
      echo "Show version locks for key tools."
      ;;
    snapshot)
      echo "Capture a baseline system snapshot."
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
    verify)
      echo "Run post-merge verification checks."
      ;;
    tools)
      echo "Browse or install toolchain components."
      ;;
    aliases)
      echo "List, search, and explain configured aliases."
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
    setup)
      echo "Interactive setup for profiles, features, and secrets."
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
      echo "Manage secrets (set/get/list/load/provider)."
      ;;
    env)
      echo "Load secret buckets into shell exports."
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
    fleet)
      echo "Show fleet node status, drift, and namespace."
      ;;
    upgrade)
      echo "Update system toolchains, plugins, and dotfiles."
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
    metrics)
      echo "Show recent observability metrics from JSONL."
      ;;
    cache-refresh | prewarm)
      echo "Regenerate shell caches for ultra-fast startup."
      ;;
    search)
      echo "Find commands by keyword."
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
  shift 2 || true
  local version summary

  for arg in "$@"; do
    case "$arg" in
      --json | -j)
        return
        ;;
    esac
  done

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
