#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC2034
# =============================================================================
# Dotfiles Heal Script - Auto-repair common dotfiles issues
# Runs diagnostics and attempts automatic fixes
# Usage: ./scripts/ops/heal.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOTFILES_SOURCE="$REPO_ROOT"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
HEAL_LOG="$STATE_DIR/heal.log"

# Colors (respect NO_COLOR: https://no-color.org)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Logging
ui_init
log() { printf '%b\n' "$*"; }
log_info() { ui_info "$*"; }
log_success() { ui_ok "$*"; }
log_warn() { ui_warn "$*"; }
log_error() { ui_err "$*"; }
log_step() {
  echo ""
  ui_header "$*"
}
log_dry() { ui_warn "DRY-RUN" "Would: $*"; }

# Persistent logging
persist_log() {
  mkdir -p "$STATE_DIR"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >>"$HEAL_LOG"
}

# Options
DRY_RUN=0
FORCE=0
FIXES_APPLIED=0
ISSUES_FOUND=0
CHEZMOI_APPLIED=0

usage() {
  cat <<EOF
Dotfiles Heal - Auto-repair common issues

Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run   Preview what would be fixed without making changes
  -f, --force     Skip confirmation prompts
  -h, --help      Show this help message

Environment:
  DOTFILES_NONINTERACTIVE=1   Skip all interactive prompts (same as --force)

Repairs:
  - Missing core tools (zsh, chezmoi, starship, rg, bat, fzf, zoxide, atuin, yazi, zellij)
  - Missing frontier tools (nu, pueue, wasmtime, sops, age)
  - Broken symlinks in \$HOME (depth 3)
  - Chezmoi drift (re-applies dotfiles)
  - Missing critical files (.zshrc, .bashrc, .profile)
  - Missing XDG config directories

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n | --dry-run)
      DRY_RUN=1
      shift
      ;;
    -f | --force)
      FORCE=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# =============================================================================
# Backup before making changes
# =============================================================================

create_pre_heal_backup() {
  local rollback_script="$REPO_ROOT/scripts/ops/rollback.sh"
  if [[ -f "$rollback_script" ]]; then
    log_info "Creating backup before heal..."
    bash "$rollback_script" backup --force 2>/dev/null || true
  else
    # Minimal inline backup
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/backup_${timestamp}_pre_heal"
    mkdir -p "$backup_path"
    for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
      if [[ -f "$f" ]]; then
        cp -a "$f" "$backup_path/" 2>/dev/null || true
      fi
    done
    log_info "Backup created at $backup_path"
  fi
}

# =============================================================================
# Repair Functions
# =============================================================================

# Helper to check command (mise-aware, mirrors doctor.sh)
check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    return 0
  fi
  # Fallback: check if installed via mise
  if command -v mise &>/dev/null; then
    if mise ls --installed 2>/dev/null | grep -qE "($cmd|aqua:.*$cmd)"; then
      return 0
    fi
  fi
  return 1
}

detect_pkg_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v nix-env >/dev/null 2>&1; then
    echo "nix"
  else
    echo ""
  fi
}

install_package() {
  local pkg="$1"
  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  case "$pkg_mgr" in
    brew) brew install --quiet "$pkg" >/dev/null 2>&1 ;;
    apt) sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1 ;;
    dnf) sudo dnf install -y -q "$pkg" >/dev/null 2>&1 ;;
    pacman) sudo pacman -S --noconfirm --quiet "$pkg" >/dev/null 2>&1 ;;
    nix) nix-env -iA "nixpkgs.$pkg" >/dev/null 2>&1 ;;
    *)
      log_error "No supported package manager found. Install '$pkg' manually."
      return 1
      ;;
  esac
}

# Map command names to package names per package manager
get_package_name() {
  local cmd="$1"
  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  case "$cmd" in
    rg) echo "ripgrep" ;;
    bat) echo "bat" ;;
    fzf) echo "fzf" ;;
    zsh) echo "zsh" ;;
    age) echo "age" ;;
    *) echo "$cmd" ;;
  esac
}

# =============================================================================
# Animated Package Installer (inspired by charm.sh/bubbletea)
# =============================================================================

_SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

_progress_bar() {
  local current=$1 total=$2 width=20
  if [[ $total -eq 0 ]]; then return; fi
  local filled=$((current * width / total))
  local empty=$((width - filled))
  printf '\033[38;5;63m'
  local i
  for ((i = 0; i < filled; i++)); do printf '█'; done
  printf '\033[0;2m'
  for ((i = 0; i < empty; i++)); do printf '░'; done
  printf '\033[0m'
}

# Run a command with animated spinner + progress bar
# Usage: _pkg_install "label" completed total command [args...]
_pkg_install() {
  local label="$1" completed="$2" total="$3"
  shift 3

  # Non-terminal: simple line output
  if [[ ! -t 1 ]]; then
    if "$@" >/dev/null 2>&1; then
      printf '  \033[38;5;42m✓\033[0m %s\n' "$label"
      return 0
    else
      printf '  \033[38;5;196m✗\033[0m %s\n' "$label"
      return 1
    fi
  fi

  local rc_file
  rc_file=$(mktemp)

  # Run install in background, capture exit code
  ( "$@" >/dev/null 2>&1; echo $? >"$rc_file" ) &
  local pid=$!

  # Animate spinner in foreground
  local fi=0 w
  w=${#total}
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  \033[38;5;63m%s\033[0m Installing \033[38;5;211m%s\033[0m  ' \
      "${_SPIN[$fi]}" "$label"
    _progress_bar "$completed" "$total"
    printf ' %*d/%d ' "$w" "$((completed + 1))" "$total"
    fi=$(( (fi + 1) % ${#_SPIN[@]} ))
    sleep 0.08
  done
  wait "$pid" 2>/dev/null

  local rc
  rc=$(cat "$rc_file" 2>/dev/null || echo 1)
  rm -f "$rc_file"

  # Clear spinner line, print result
  printf '\r\033[K'
  if [[ "$rc" == "0" ]]; then
    printf '  \033[38;5;42m✓\033[0m %s\n' "$label"
  else
    printf '  \033[38;5;196m✗\033[0m %s\n' "$label"
  fi
  return "$rc"
}

# Install a single package (dispatcher for _pkg_install to call in subshell)
_do_install() {
  local cmd="$1"
  local pkg_mgr="$2"
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  # Binary installers for tools not in standard apt repos
  if [[ "$pkg_mgr" == "apt" ]]; then
    case "$cmd" in
      starship)
        curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
        return $?
        ;;
      atuin)
        curl -fsSL https://setup.atuin.sh | bash -s -- --yes
        return $?
        ;;
      yazi)
        local arch
        arch=$(uname -m)
        local url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${arch}-unknown-linux-musl.zip"
        local tmp
        tmp=$(mktemp -d)
        command -v unzip >/dev/null 2>&1 || sudo apt-get install -y -qq unzip
        curl -fsSL -o "$tmp/yazi.zip" "$url" \
          && (cd "$tmp" && unzip -oq yazi.zip) \
          && install -m 755 "$tmp"/yazi-*/yazi "$bin_dir/yazi"
        local rc=$?
        rm -rf "$tmp"
        return $rc
        ;;
      zellij)
        local arch
        arch=$(uname -m)
        local url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${arch}-unknown-linux-musl.tar.gz"
        local tmp
        tmp=$(mktemp -d)
        curl -fsSL -o "$tmp/zellij.tar.gz" "$url" \
          && tar xzf "$tmp/zellij.tar.gz" -C "$tmp" \
          && install -m 755 "$tmp/zellij" "$bin_dir/zellij"
        local rc=$?
        rm -rf "$tmp"
        return $rc
        ;;
    esac
  fi

  # System package manager
  local pkg
  pkg=$(get_package_name "$cmd")
  install_package "$pkg"
}

heal_missing_dependencies() {
  log_step "Checking dependencies"
  local deps=(zsh chezmoi starship rg bat fzf zoxide atuin yazi zellij)
  local frontier_deps=("nushell" "pueue" "wasmtime" "sops" "age")
  local all_missing=()

  # Detect missing core tools
  for cmd in "${deps[@]}"; do
    if check_cmd "$cmd"; then continue; fi
    if [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then continue; fi
    all_missing+=("$cmd")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  done

  # Detect missing frontier tools
  for cmd in "${frontier_deps[@]}"; do
    local check_name="$cmd"
    [[ "$cmd" == "nushell" ]] && check_name="nu"
    if ! check_cmd "$check_name"; then
      all_missing+=("$cmd")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#all_missing[@]} -eq 0 ]]; then
    log_success "All dependencies present"
    return 0
  fi

  local total=${#all_missing[@]}
  local completed=0
  local installed=0
  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  echo ""
  for cmd in "${all_missing[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "install '$cmd'"
      completed=$((completed + 1))
      continue
    fi

    # Frontier tools: try mise first
    local is_frontier=0
    for ft in "${frontier_deps[@]}"; do
      [[ "$ft" == "$cmd" ]] && is_frontier=1 && break
    done

    if [[ "$is_frontier" == "1" ]] && command -v mise >/dev/null 2>&1; then
      local mise_name="$cmd"
      case "$cmd" in
        nushell) mise_name="aqua:nushell/nushell" ;;
        pueue) mise_name="aqua:Nukesor/pueue/pueue" ;;
      esac
      if _pkg_install "$cmd" "$completed" "$total" mise use -g "$mise_name"; then
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        installed=$((installed + 1))
        persist_log "HEAL: installed $cmd via mise"
        completed=$((completed + 1))
        continue
      fi
    fi

    if [[ -z "$pkg_mgr" ]]; then
      printf '  \033[38;5;196m✗\033[0m %s (no package manager)\n' "$cmd"
      completed=$((completed + 1))
      continue
    fi

    if _pkg_install "$cmd" "$completed" "$total" _do_install "$cmd" "$pkg_mgr"; then
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      installed=$((installed + 1))
      persist_log "HEAL: installed $cmd"

      # Post-install hooks (run in parent scope)
      case "$cmd" in
        bat)
          if [[ "$pkg_mgr" == "apt" ]] && command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
          fi
          ;;
        atuin) export PATH="$HOME/.atuin/bin:$PATH" ;;
      esac
    fi
    completed=$((completed + 1))
  done

  if [[ "$DRY_RUN" != "1" ]]; then
    echo ""
    printf '  \033[1;38;5;42mDone!\033[0m Installed %d/%d packages.\n' "$installed" "$total"
  fi
}

heal_broken_symlinks() {
  log_step "Checking for broken symlinks"
  local broken=()

  while IFS= read -r -d '' link; do
    # Skip known false positives (e.g., Chrome lock files in backups)
    [[ "$link" == *"google-chrome-backup"* ]] && continue

    if [[ ! -e "$link" ]]; then
      broken+=("$link")
    fi
  done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)

  # Special handling for common transient/app locks that dot doctor reported
  local lock_patterns=("SingletonLock" "SingletonCookie")

  if [[ ${#broken[@]} -eq 0 ]]; then
    log_success "No broken symlinks found"
    return 0
  fi

  ISSUES_FOUND=$((ISSUES_FOUND + ${#broken[@]}))
  log_warn "${#broken[@]} broken symlink(s) found"

  for link in "${broken[@]}"; do
    local target
    target=$(readlink "$link" 2>/dev/null || echo "unknown")
    local filename
    filename=$(basename "$link")

    # Auto-fix lock files without prompt if they are clearly broken
    local is_lock=0
    for pat in "${lock_patterns[@]}"; do
      if [[ "$filename" == *"$pat"* ]]; then
        is_lock=1
        break
      fi
    done

    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "remove broken symlink: $link -> $target"
    else
      if [[ "$is_lock" == "0" ]] && [[ "$FORCE" != "1" ]] && [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
        read -rp "Remove broken symlink $link -> $target? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
          log_info "Skipped: $link"
          continue
        fi
      fi
      rm -f "$link"
      log_success "Removed broken symlink: $link -> $target"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      persist_log "HEAL: removed broken symlink $link"
    fi
  done
}

heal_chezmoi_drift() {
  log_step "Checking chezmoi state"

  if ! command -v chezmoi >/dev/null 2>&1; then
    log_warn "chezmoi not installed, skipping drift check"
    return 0
  fi

  local status_output
  status_output=$(chezmoi status 2>/dev/null || echo "")

  if [[ -z "$status_output" ]]; then
    log_success "Chezmoi state is synchronized"
    return 0
  fi

  local drift_count
  drift_count=$(echo "$status_output" | wc -l | tr -d ' ')
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
  log_warn "$drift_count file(s) out of sync"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'chezmoi apply --force' to re-sync"
    echo "$status_output" | while read -r line; do
      log_info "  $line"
    done
  else
    log_info "Re-applying dotfiles with chezmoi..."
    if chezmoi apply --force; then
      log_success "Chezmoi re-applied successfully"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      CHEZMOI_APPLIED=1
      persist_log "HEAL: chezmoi apply --force ($drift_count files drifted)"
    else
      log_error "Chezmoi apply failed"
    fi
  fi
}

heal_missing_critical_files() {
  log_step "Checking critical files"
  local critical_files=(
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.profile"
  )
  local missing=()

  for file in "${critical_files[@]}"; do
    if [[ ! -f "$file" ]] && [[ ! -L "$file" ]]; then
      missing+=("$file")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_success "All critical shell configs present"
    return 0
  fi

  log_warn "Missing critical files: ${missing[*]}"

  if ! command -v chezmoi >/dev/null 2>&1; then
    log_error "chezmoi not available to regenerate files"
    return 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'chezmoi apply --force' to regenerate missing files"
  elif [[ "$CHEZMOI_APPLIED" == "1" ]]; then
    log_info "chezmoi already re-applied during drift repair, verifying files..."
    local restored=0
    for file in "${missing[@]}"; do
      if [[ -f "$file" ]] || [[ -L "$file" ]]; then
        log_success "Restored (via earlier apply): $file"
        restored=$((restored + 1))
      else
        log_warn "Still missing after apply: $file"
      fi
    done
    FIXES_APPLIED=$((FIXES_APPLIED + restored))
  else
    log_info "Re-applying chezmoi to regenerate missing files..."
    if chezmoi apply --force; then
      CHEZMOI_APPLIED=1
      # Verify files were restored
      local restored=0
      for file in "${missing[@]}"; do
        if [[ -f "$file" ]] || [[ -L "$file" ]]; then
          log_success "Restored: $file"
          restored=$((restored + 1))
        else
          log_warn "Still missing after apply: $file"
        fi
      done
      FIXES_APPLIED=$((FIXES_APPLIED + restored))
      persist_log "HEAL: regenerated $restored critical file(s)"
    else
      log_error "Chezmoi apply failed"
    fi
  fi
}

heal_mise_tools() {
  log_step "Checking mise-managed tools"
  if ! command -v mise >/dev/null 2>&1; then
    log_info "mise not found, skipping tool check"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'mise install' to ensure all tools are present"
  else
    log_info "Running 'mise install'..."
    if mise install; then
      log_success "Mise tools verified"

      # Start pueue daemon if it was just installed but not running
      if command -v pueued >/dev/null && ! pueue status >/dev/null 2>&1; then
        log_info "Starting pueue daemon..."
        pueued -d
      fi
    else
      log_warn "Mise install had issues"
    fi
  fi
}

heal_missing_xdg_dirs() {
  log_step "Checking XDG config directories"
  local xdg_dirs=(
    "$HOME/.config/shell"
    "$HOME/.config/nvim"
    "$HOME/.config/git"
  )
  local missing=()

  for dir in "${xdg_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      missing+=("$dir")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_success "All XDG config directories present"
    return 0
  fi

  log_warn "Missing XDG directories: ${missing[*]}"

  for dir in "${missing[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "create directory: $dir"
    else
      mkdir -p "$dir"
      log_success "Created: $dir"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      persist_log "HEAL: created directory $dir"
    fi
  done
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  echo "=========================================="
  echo "     Dotfiles Heal - Auto-Repair"
  echo "=========================================="

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "Running in dry-run mode (no changes will be made)"
  fi

  # Confirm before making changes (unless --force, --dry-run, or non-interactive)
  if [[ "$DRY_RUN" != "1" ]] && [[ "$FORCE" != "1" ]] && [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    echo ""
    log_warn "This will attempt to auto-repair your dotfiles environment."
    log_info "A backup will be created before any changes are made."
    read -rp "Continue? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      log_info "Aborted."
      exit 0
    fi
  fi

  # Create backup before making changes
  if [[ "$DRY_RUN" != "1" ]]; then
    create_pre_heal_backup
  fi

  # Run all repairs
  heal_missing_dependencies || true
  heal_mise_tools || true
  heal_broken_symlinks || true
  heal_chezmoi_drift || true
  heal_missing_critical_files || true
  heal_missing_xdg_dirs || true

  # Summary
  echo ""
  echo "=========================================="
  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ $ISSUES_FOUND -eq 0 ]]; then
      log_success "No issues found. System is healthy."
    else
      log_info "Found $ISSUES_FOUND issue(s). Run without --dry-run to apply fixes."
    fi
  else
    if [[ $ISSUES_FOUND -eq 0 ]]; then
      log_success "No issues found. System is healthy."
    elif [[ $FIXES_APPLIED -gt 0 ]]; then
      log_success "Applied $FIXES_APPLIED fix(es) for $ISSUES_FOUND issue(s) found."
      persist_log "HEAL_COMPLETE: $FIXES_APPLIED fixes applied"
    else
      log_warn "Found $ISSUES_FOUND issue(s) but no fixes could be applied."
      log_info "Try running 'dot doctor' for detailed diagnostics."
    fi
  fi
  echo "=========================================="
}

main
