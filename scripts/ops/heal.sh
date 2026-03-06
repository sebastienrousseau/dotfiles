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
    brew) brew install "$pkg" ;;
    apt) sudo apt-get install -y "$pkg" ;;
    dnf) sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    nix) nix-env -iA "nixpkgs.$pkg" ;;
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

# Binary installer for tools not in standard apt repos
_install_via_binary() {
  local cmd="$1"
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  case "$cmd" in
    starship)
      log_info "Installing starship via curl installer..."
      if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes; then
        log_success "Installed starship"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        persist_log "HEAL: installed starship via curl installer"
        return 0
      fi
      ;;
    atuin)
      log_info "Installing atuin via install script..."
      if curl -fsSL https://setup.atuin.sh | sh -s -- --yes 2>/dev/null || \
         curl -fsSL https://setup.atuin.sh | bash; then
        log_success "Installed atuin"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        persist_log "HEAL: installed atuin via curl installer"
        return 0
      fi
      ;;
    yazi)
      log_info "Installing yazi via GitHub release..."
      local arch
      arch=$(uname -m)
      local url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${arch}-unknown-linux-musl.zip"
      local tmp
      tmp=$(mktemp -d)
      if curl -fsSL -o "$tmp/yazi.zip" "$url" && \
         (cd "$tmp" && unzip -q yazi.zip 2>/dev/null || true) && \
         install -m 755 "$tmp"/yazi-*/yazi "$bin_dir/yazi"; then
        log_success "Installed yazi"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        persist_log "HEAL: installed yazi via GitHub release"
        rm -rf "$tmp"
        return 0
      fi
      rm -rf "$tmp"
      ;;
    zellij)
      log_info "Installing zellij via GitHub release..."
      local arch
      arch=$(uname -m)
      local url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${arch}-unknown-linux-musl.tar.gz"
      local tmp
      tmp=$(mktemp -d)
      if curl -fsSL -o "$tmp/zellij.tar.gz" "$url" && \
         tar xzf "$tmp/zellij.tar.gz" -C "$tmp" && \
         install -m 755 "$tmp/zellij" "$bin_dir/zellij"; then
        log_success "Installed zellij"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        persist_log "HEAL: installed zellij via GitHub release"
        rm -rf "$tmp"
        return 0
      fi
      rm -rf "$tmp"
      ;;
    *) return 1 ;;
  esac
  return 1
}

heal_missing_dependencies() {
  log_step "Checking core dependencies"
  # Match what dot doctor checks: Core Shells + Modern CLI Tools
  local deps=(zsh chezmoi starship rg bat fzf zoxide atuin yazi zellij)
  # Frontier tools (doctor reports these as warnings)
  local frontier_deps=("nushell" "pueue" "wasmtime" "sops" "age")
  local missing=()
  local missing_frontier=()

  for cmd in "${deps[@]}"; do
    if check_cmd "$cmd"; then
      continue
    fi
    # On Debian/Ubuntu, bat is installed as batcat
    if [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then
      continue
    fi
    missing+=("$cmd")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  done

  # Frontier tools: check using check_cmd (mise-aware)
  for cmd in "${frontier_deps[@]}"; do
    local check_name="$cmd"
    # 'nu' is the binary name for nushell
    [[ "$cmd" == "nushell" ]] && check_name="nu"
    if ! check_cmd "$check_name"; then
      missing_frontier+=("$cmd")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]] && [[ ${#missing_frontier[@]} -eq 0 ]]; then
    log_success "All dependencies present"
    return 0
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing core dependencies: ${missing[*]}"
  fi

  if [[ ${#missing_frontier[@]} -gt 0 ]]; then
    log_warn "Missing frontier tools: ${missing_frontier[*]}"
  fi

  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  # Try mise for frontier tools if available
  if command -v mise >/dev/null 2>&1 && [[ ${#missing_frontier[@]} -gt 0 ]]; then
    for cmd in "${missing_frontier[@]}"; do
      local mise_name=$cmd
      # Map to specific aqua providers if registry lookup is failing
      case "$cmd" in
        nushell) mise_name="aqua:nushell/nushell" ;;
        pueue) mise_name="aqua:Nukesor/pueue/pueue" ;;
      esac

      if [[ "$DRY_RUN" == "1" ]]; then
        log_dry "install '$mise_name' via mise"
      else
        log_info "Installing $mise_name via mise..."
        if mise use -g "$mise_name"; then
          log_success "Installed $cmd via mise"
          FIXES_APPLIED=$((FIXES_APPLIED + 1))
          persist_log "HEAL: installed $cmd via mise"
          # Filter it out of the missing list
          local temp_list=()
          for item in "${missing_frontier[@]}"; do
            [[ "$item" != "$cmd" ]] && temp_list+=("$item")
          done
          missing_frontier=("${temp_list[@]}")
        fi
      fi
    done
  fi

  # System package manager fallback for core deps
  if [[ ${#missing[@]} -eq 0 ]]; then return 0; fi

  if [[ -z "$pkg_mgr" ]]; then
    log_error "No supported package manager detected. Install manually: ${missing[*]}"
    return 1
  fi

  for cmd in "${missing[@]}"; do
    local pkg
    pkg=$(get_package_name "$cmd")

    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "install '$pkg' via $pkg_mgr"
    else
      # Tools not in standard apt repos — use binary installers
      if [[ "$pkg_mgr" == "apt" ]] && _install_via_binary "$cmd"; then
        continue
      fi

      log_info "Installing $pkg via $pkg_mgr..."
      if install_package "$pkg"; then
        log_success "Installed $pkg"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        persist_log "HEAL: installed $pkg via $pkg_mgr"

        # On Debian/Ubuntu, bat installs as batcat — create symlink
        if [[ "$cmd" == "bat" ]] && [[ "$pkg_mgr" == "apt" ]] && command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
          local bin_dir="$HOME/.local/bin"
          mkdir -p "$bin_dir"
          ln -sf "$(command -v batcat)" "$bin_dir/bat"
          log_success "Created bat -> batcat symlink"
        fi
      else
        log_error "Failed to install $pkg"
      fi
    fi
  done
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
