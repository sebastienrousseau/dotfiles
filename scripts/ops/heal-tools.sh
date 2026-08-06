#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# =============================================================================

HEAL_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/verified-download.sh disable=SC1091
source "$HEAL_TOOLS_DIR/../../lib/dot/verified-download.sh"
# heal-tools.sh — Tool installation helpers for heal.sh
# Sourced by heal.sh; inherits set -euo pipefail, ui.sh, and shared variables.
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
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  elif command -v pkg >/dev/null 2>&1; then
    echo "pkg"
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
    apt)
      if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo not found — cannot install '$pkg' via apt"
        return 1
      fi
      sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1
      ;;
    dnf)
      if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo not found — cannot install '$pkg' via dnf"
        return 1
      fi
      sudo dnf install -y -q "$pkg" >/dev/null 2>&1
      ;;
    pacman)
      if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo not found — cannot install '$pkg' via pacman"
        return 1
      fi
      sudo pacman -S --noconfirm --quiet "$pkg" >/dev/null 2>&1
      ;;
    zypper)
      if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo not found — cannot install '$pkg' via zypper"
        return 1
      fi
      sudo zypper --quiet install -y "$pkg" >/dev/null 2>&1
      ;;
    apk)
      if command -v sudo >/dev/null 2>&1; then
        sudo apk add --quiet "$pkg" >/dev/null 2>&1
      else
        apk add --quiet "$pkg" >/dev/null 2>&1
      fi
      ;;
    pkg)
      # FreeBSD/OpenBSD/NetBSD — install as root when available.
      if command -v sudo >/dev/null 2>&1; then
        sudo pkg install -y "$pkg" >/dev/null 2>&1
      else
        pkg install -y "$pkg" >/dev/null 2>&1
      fi
      ;;
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
# Animated Package Installer — delegates to ui.sh ui_run_cmd
# =============================================================================

# Usage: _pkg_install "label" completed total command [args...]
_pkg_install() { ui_run_cmd "$@"; }

_mise_tool_specs() {
  case "$1" in
    nushell) printf '%s\n' 'aqua:nushell/nushell@0.114.1' ;;
    pueue)
      printf '%s\n' 'aqua:Nukesor/pueue/pueue@4.0.4'
      printf '%s\n' 'aqua:Nukesor/pueue/pueued@4.0.4'
      ;;
    wasmtime) printf '%s\n' 'wasmtime@47.0.3' ;;
    sops) printf '%s\n' 'sops@3.13.3' ;;
    yazi) printf '%s\n' 'yazi@26.5.6' ;;
    zellij) printf '%s\n' 'zellij@0.44.3' ;;
    *) return 1 ;;
  esac
}

_install_with_mise() {
  local cmd="$1" spec
  command -v mise >/dev/null 2>&1 || return 1
  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    # --pin writes an exact version to the user's writable global config;
    # aqua/ubi backends verify publisher-provided checksums before install.
    mise use --global --pin "$spec" || return 1
  done < <(_mise_tool_specs "$cmd")
}

# Install a single package (dispatcher for _pkg_install to call in subshell)
_do_install() {
  local cmd="$1"
  local pkg_mgr="$2"

  case "$cmd" in
    nushell | pueue | wasmtime | sops | yazi | zellij)
      if _install_with_mise "$cmd"; then
        return 0
      fi
      log_warn "mise install unavailable for $cmd; trying $pkg_mgr"
      ;;
  esac

  # Binary/curl installers for tools not in standard apt repos
  case "$cmd" in
    starship)
      local installer
      installer=$(umask 077 && mktemp)
      if ! download_verified_script https://starship.rs/install.sh "$installer"; then
        rm -f "$installer"
        log_error "Failed to download starship installer"
        return 1
      fi
      sh "$installer" --yes
      local rc=$?
      rm -f "$installer"
      return $rc
      ;;
    atuin)
      local installer
      installer=$(umask 077 && mktemp)
      if ! download_verified_script https://setup.atuin.sh "$installer"; then
        rm -f "$installer"
        log_error "Failed to download atuin installer"
        return 1
      fi
      bash "$installer" --yes
      local rc=$?
      rm -f "$installer"
      return $rc
      ;;
  esac

  # System package manager
  local pkg
  pkg=$(get_package_name "$cmd")
  install_package "$pkg"
}

heal_missing_dependencies() {
  log_step "Checking dependencies"
  # All tools that dot doctor checks — unified list
  local deps=(
    zsh chezmoi starship rg bat fzf zoxide atuin yazi zellij
    nushell pueue wasmtime sops age hyperfine
  )
  local all_missing=()

  for cmd in "${deps[@]}"; do
    local check_name="$cmd"
    [[ "$cmd" == "nushell" ]] && check_name="nu"
    if check_cmd "$check_name"; then continue; fi
    if [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then continue; fi
    all_missing+=("$cmd")
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
  done

  MISSING_DEPS_FOUND=${#all_missing[@]}

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

heal_mise_tools() {
  if ! command -v mise >/dev/null 2>&1; then
    return 0
  fi

  # Avoid blocking every heal run. Only ensure mise tools when deps are missing
  # or when explicitly requested.
  if [[ "${DOTFILES_HEAL_MISE_INSTALL:-0}" != "1" ]] && [[ "${MISSING_DEPS_FOUND:-0}" -eq 0 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'mise install' to ensure all tools are present"
  else
    if _pkg_install "mise tools" 0 1 mise install; then
      # Start pueue daemon if it was just installed but not running
      if command -v pueued >/dev/null && ! pueue status >/dev/null 2>&1; then
        pueued -d 2>/dev/null || true
      fi
    fi
  fi
}
