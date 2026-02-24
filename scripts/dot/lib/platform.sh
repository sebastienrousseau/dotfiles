#!/usr/bin/env bash
# Dotfiles CLI Platform Abstraction
# Unified helpers for macOS, Linux, and WSL parity.

set -euo pipefail

dot_is_wsl() {
  [[ -f /proc/sys/kernel/osrelease ]] && grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease
}

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

# =============================================================================
# Container Detection
# =============================================================================

# Check if running inside a container
dot_is_container() {
  # Docker/Podman: /.dockerenv or /run/.containerenv
  [[ -f /.dockerenv ]] && return 0
  [[ -f /run/.containerenv ]] && return 0

  # cgroup-based detection (more reliable)
  if [[ -f /proc/1/cgroup ]]; then
    grep -qE '(docker|containerd|podman|lxc|kubepods)' /proc/1/cgroup 2>/dev/null && return 0
  fi

  # Kubernetes pod
  [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]] && return 0

  return 1
}

# Check if running in a dev container (VS Code, Codespaces, etc.)
dot_is_devcontainer() {
  # VS Code Dev Container
  [[ -n "${REMOTE_CONTAINERS:-}" ]] && return 0
  [[ -n "${REMOTE_CONTAINERS_IPC:-}" ]] && return 0

  # GitHub Codespaces
  [[ -n "${CODESPACES:-}" ]] && return 0
  [[ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]] && return 0

  # Gitpod
  [[ -n "${GITPOD_WORKSPACE_ID:-}" ]] && return 0

  # DevPod
  [[ -n "${DEVPOD:-}" ]] && return 0

  # Generic devcontainer marker
  [[ -f /workspaces/.codespaces/.persistedshare/dotfiles ]] && return 0

  return 1
}

# Check if running in CI environment
dot_is_ci() {
  [[ -n "${CI:-}" ]] && return 0
  [[ -n "${GITHUB_ACTIONS:-}" ]] && return 0
  [[ -n "${GITLAB_CI:-}" ]] && return 0
  [[ -n "${CIRCLECI:-}" ]] && return 0
  [[ -n "${JENKINS_URL:-}" ]] && return 0
  [[ -n "${TRAVIS:-}" ]] && return 0
  return 1
}

# Get container runtime type
dot_container_type() {
  if [[ -n "${CODESPACES:-}" ]]; then
    echo "codespaces"
  elif [[ -n "${GITPOD_WORKSPACE_ID:-}" ]]; then
    echo "gitpod"
  elif [[ -n "${DEVPOD:-}" ]]; then
    echo "devpod"
  elif [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
    echo "devcontainer"
  elif [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
    echo "kubernetes"
  elif [[ -f /.dockerenv ]]; then
    echo "docker"
  elif [[ -f /run/.containerenv ]]; then
    echo "podman"
  else
    echo "none"
  fi
}

# Check if GUI is available
dot_has_gui() {
  # Containers typically don't have GUI
  dot_is_container && return 1
  dot_is_ci && return 1

  # Check for display
  [[ -n "${DISPLAY:-}" ]] && return 0
  [[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0

  # macOS always has GUI (unless SSH)
  [[ "$(uname -s)" == "Darwin" && -z "${SSH_CONNECTION:-}" ]] && return 0

  return 1
}

# =============================================================================
# Path Helpers
# =============================================================================

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
