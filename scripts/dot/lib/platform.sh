#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Dotfiles CLI Platform Abstraction
# Unified helpers for macOS, Linux, and WSL parity.

set -euo pipefail

if ! declare -F dot_is_wsl >/dev/null; then
  dot_is_wsl() {
    [[ -f /proc/sys/kernel/osrelease ]] && grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease
  }
fi

dot_platform_id() {
  case "$(uname -s)" in
    Darwin) printf "%s\n" "macos" ;;
    Linux)
      if dot_is_wsl; then
        printf "%s\n" "wsl"
      else
        printf "%s\n" "linux"
      fi
      ;;
    *) printf "%s\n" "unknown" ;;
  esac
}

dot_host_os() {
  if dot_is_wsl; then
    printf "%s\n" "windows"
    return
  fi
  case "$(uname -s)" in
    Darwin) printf "%s\n" "macos" ;;
    Linux) printf "%s\n" "linux" ;;
    *) printf "%s\n" "unknown" ;;
  esac
}

# Convert host-native path into Linux path when inside WSL.
dot_path_to_unix() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    return 1
  fi
  if dot_is_wsl && command -v wslpath >/dev/null 2>&1; then
    wslpath -u "$p"
    return
  fi
  printf "%s\n" "$p"
}

# Convert Linux path into host-native path when inside WSL.
dot_path_to_native() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    return 1
  fi
  if dot_is_wsl && command -v wslpath >/dev/null 2>&1; then
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
    linux)
      xdg-open "$target"
      ;;
    *)
      return 1
      ;;
  esac
}
