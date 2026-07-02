#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/*.sh; inherits set -euo pipefail.
# Dotfiles CLI Platform Abstraction
# Unified helpers for macOS, Linux, and WSL parity.

set -euo pipefail

# These are called repeatedly within one `dot` invocation (dot_host_os itself
# calls dot_platform_id + dot_is_wsl), each forking `uname`/`grep`. Memoise per
# process — the platform can't change mid-run. Caches are process-local (not
# exported), so child processes still resolve fresh.
if ! declare -F dot_is_wsl >/dev/null; then
  dot_is_wsl() {
    if [[ -n "${_DOT_IS_WSL:-}" ]]; then
      return "$_DOT_IS_WSL"
    fi
    if [[ -f /proc/sys/kernel/osrelease ]] && grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease; then
      _DOT_IS_WSL=0
    else
      _DOT_IS_WSL=1
    fi
    return "$_DOT_IS_WSL"
  }
fi

dot_platform_id() {
  if [[ -n "${_DOT_PLATFORM_ID:-}" ]]; then
    printf "%s\n" "$_DOT_PLATFORM_ID"
    return
  fi
  case "$(uname -s)" in
    Darwin) _DOT_PLATFORM_ID="macos" ;;
    Linux)
      if dot_is_wsl; then
        _DOT_PLATFORM_ID="wsl"
      else
        _DOT_PLATFORM_ID="linux"
      fi
      ;;
    FreeBSD | OpenBSD | NetBSD | DragonFly) _DOT_PLATFORM_ID="bsd" ;;
    *) _DOT_PLATFORM_ID="unknown" ;;
  esac
  printf "%s\n" "$_DOT_PLATFORM_ID"
}

dot_host_os() {
  if [[ -n "${_DOT_HOST_OS:-}" ]]; then
    printf "%s\n" "$_DOT_HOST_OS"
    return
  fi
  if dot_is_wsl; then
    _DOT_HOST_OS="windows"
    printf "%s\n" "$_DOT_HOST_OS"
    return
  fi
  case "$(uname -s)" in
    Darwin) _DOT_HOST_OS="macos" ;;
    Linux) _DOT_HOST_OS="linux" ;;
    FreeBSD | OpenBSD | NetBSD | DragonFly) _DOT_HOST_OS="bsd" ;;
    *) _DOT_HOST_OS="unknown" ;;
  esac
  printf "%s\n" "$_DOT_HOST_OS"
}

# Convert host-native path into Linux path when inside WSL.
#
# Contract:
#   - In WSL: requires `wslpath`. Returns 2 (with a stderr error) if
#     missing — callers must not silently treat a Windows-style path
#     as Linux-safe.
#   - Outside WSL: paths are already Linux/macOS paths; echoes the
#     input unchanged and returns 0.
#   - Empty input returns 1 (usage error).
dot_path_to_unix() {
  local p="${1:-}"
  [[ -n "$p" ]] || return 1
  if dot_is_wsl; then
    if ! command -v wslpath >/dev/null 2>&1; then
      printf "dot_path_to_unix: wslpath required in WSL but not found\n" >&2
      return 2
    fi
    wslpath -u "$p"
    return
  fi
  printf "%s\n" "$p"
}

# Convert Linux path into host-native path when inside WSL.
# Same contract as dot_path_to_unix (see above).
dot_path_to_native() {
  local p="${1:-}"
  [[ -n "$p" ]] || return 1
  if dot_is_wsl; then
    if ! command -v wslpath >/dev/null 2>&1; then
      printf "dot_path_to_native: wslpath required in WSL but not found\n" >&2
      return 2
    fi
    wslpath -w "$p"
    return
  fi
  printf "%s\n" "$p"
}

dot_open_path() {
  local target="${1:-}"
  [[ -n "$target" ]] || return 1

  case "$(dot_platform_id)" in
    macos)
      command open "$target"
      ;;
    wsl)
      if command -v wslview >/dev/null 2>&1; then
        wslview "$target"
      else
        explorer.exe "$(dot_path_to_native "$target")"
      fi
      ;;
    linux | bsd)
      xdg-open "$target"
      ;;
    *)
      return 1
      ;;
  esac
}

dot_require_platform() {
  local current
  current="$(dot_platform_id)"
  for allowed in "$@"; do
    [[ "$current" == "$allowed" ]] && return 0
  done
  echo "  ! This command requires $* (detected: $current)" >&2
  exit 2
}
