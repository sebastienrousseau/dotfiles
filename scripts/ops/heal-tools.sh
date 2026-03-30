#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# =============================================================================
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

# Resolve latest GitHub release tag for a repo
_gh_latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's|.*/||'
}

# Install a single package (dispatcher for _pkg_install to call in subshell)
_do_install() {
  local cmd="$1"
  local pkg_mgr="$2"
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  # Binary/curl installers for tools not in standard apt repos
  case "$cmd" in
    starship)
      local installer
      installer=$(umask 077 && mktemp)
      if ! curl -fsSL -o "$installer" https://starship.rs/install.sh; then
        rm -f "$installer"
        log_error "Failed to download starship installer"
        return 1
      fi
      if ! head -1 "$installer" | grep -q '^#!/'; then
        rm -f "$installer"
        log_error "starship installer does not look like a shell script"
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
      if ! curl -fsSL -o "$installer" https://setup.atuin.sh; then
        rm -f "$installer"
        log_error "Failed to download atuin installer"
        return 1
      fi
      if ! head -1 "$installer" | grep -q '^#!/'; then
        rm -f "$installer"
        log_error "atuin installer does not look like a shell script"
        return 1
      fi
      bash "$installer" --yes
      local rc=$?
      rm -f "$installer"
      return $rc
      ;;
    nushell)
      local arch tag ver
      arch=$(uname -m)
      tag=$(_gh_latest_tag "nushell/nushell")
      ver="${tag#v}"
      local tmp
      tmp=$(mktemp -d)
      curl -fsSL -o "$tmp/nu.tar.gz" \
        "https://github.com/nushell/nushell/releases/download/${tag}/nu-${ver}-${arch}-unknown-linux-musl.tar.gz" &&
        tar xzf "$tmp/nu.tar.gz" -C "$tmp" --strip-components=1 &&
        install -m 755 "$tmp/nu" "$bin_dir/nu"
      local rc=$?
      rm -rf "$tmp"
      return $rc
      ;;
    pueue)
      local arch
      arch=$(uname -m)
      curl -fsSL -o "$bin_dir/pueue" \
        "https://github.com/Nukesor/pueue/releases/latest/download/pueue-${arch}-unknown-linux-musl" &&
        chmod +x "$bin_dir/pueue"
      curl -fsSL -o "$bin_dir/pueued" \
        "https://github.com/Nukesor/pueue/releases/latest/download/pueued-${arch}-unknown-linux-musl" &&
        chmod +x "$bin_dir/pueued"
      return $?
      ;;
    wasmtime)
      local arch tag
      arch=$(uname -m)
      tag=$(_gh_latest_tag "bytecodealliance/wasmtime")
      local tmp
      tmp=$(mktemp -d)
      # xz-utils required for .tar.xz extraction
      command -v xz >/dev/null 2>&1 || sudo apt-get install -y -qq xz-utils >/dev/null 2>&1 || true
      curl -fsSL -o "$tmp/wasmtime.tar.xz" \
        "https://github.com/bytecodealliance/wasmtime/releases/download/${tag}/wasmtime-${tag}-${arch}-linux.tar.xz" &&
        tar xJf "$tmp/wasmtime.tar.xz" -C "$tmp" --strip-components=1 &&
        install -m 755 "$tmp/wasmtime" "$bin_dir/wasmtime"
      local rc=$?
      rm -rf "$tmp"
      return $rc
      ;;
    sops)
      local arch tag
      arch=$(uname -m)
      [[ "$arch" == "x86_64" ]] && arch="amd64"
      [[ "$arch" == "aarch64" ]] && arch="arm64"
      tag=$(_gh_latest_tag "getsops/sops")
      curl -fsSL -o "$bin_dir/sops" \
        "https://github.com/getsops/sops/releases/download/${tag}/sops-${tag}.linux.${arch}" &&
        chmod +x "$bin_dir/sops"
      return $?
      ;;
    hyperfine)
      local arch tag
      arch=$(uname -m)
      tag=$(_gh_latest_tag "sharkdp/hyperfine")
      local tmp
      tmp=$(mktemp -d)
      curl -fsSL -o "$tmp/hyperfine.tar.gz" \
        "https://github.com/sharkdp/hyperfine/releases/download/${tag}/hyperfine-${tag}-${arch}-unknown-linux-musl.tar.gz" &&
        tar xzf "$tmp/hyperfine.tar.gz" -C "$tmp" --strip-components=1 &&
        install -m 755 "$tmp/hyperfine" "$bin_dir/hyperfine"
      local rc=$?
      rm -rf "$tmp"
      return $rc
      ;;
    yazi)
      local arch
      arch=$(uname -m)
      local url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${arch}-unknown-linux-musl.zip"
      local tmp
      tmp=$(mktemp -d)
      command -v unzip >/dev/null 2>&1 || sudo apt-get install -y -qq unzip
      curl -fsSL -o "$tmp/yazi.zip" "$url" &&
        (cd "$tmp" && unzip -oq yazi.zip) &&
        install -m 755 "$tmp"/yazi-*/yazi "$bin_dir/yazi"
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
      curl -fsSL -o "$tmp/zellij.tar.gz" "$url" &&
        tar xzf "$tmp/zellij.tar.gz" -C "$tmp" &&
        install -m 755 "$tmp/zellij" "$bin_dir/zellij"
      local rc=$?
      rm -rf "$tmp"
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
