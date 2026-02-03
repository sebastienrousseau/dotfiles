#!/usr/bin/env bash
set -euo pipefail

# 00-container-detect.sh: Detect container environments
# Sets environment flags so downstream configs can adapt behaviour
# (e.g. simpler prompts, skip host-only tooling).
#
# Security: Uses targeted detection methods to minimize information disclosure.
# Only checks for presence of containers, not specific runtime details.

# Detect container environment using file-based indicators (preferred)
# These methods don't expose runtime details like /proc/1/cgroup would
_detect_container() {
  # Docker creates this file
  [ -f /.dockerenv ] && return 0

  # Podman/other OCI runtimes create this
  [ -f /run/.containerenv ] && return 0

  # Check for container environment variables (set by runtime)
  [ -n "${container:-}" ] && return 0

  # Systemd-nspawn sets this
  [ -n "${SYSTEMD_NSPAWN_CONTAINER:-}" ] && return 0

  # LXC/LXD detection via environment
  [ -n "${LXC_NAME:-}" ] && return 0

  # Fallback: Check cgroup v2 for container slice (minimal info exposure)
  # Only checks if we're in a container scope, not which runtime
  if [ -f /proc/self/cgroup ]; then
    grep -qsE '^0::/.*/(docker|libpod|lxc|containerd)' /proc/self/cgroup 2>/dev/null && return 0
  fi

  return 1
}

if _detect_container; then
  export DOTFILES_CONTAINER=1
fi
unset -f _detect_container

# Detect GitHub Codespaces
if [ -n "${CODESPACES:-}" ]; then
  export DOTFILES_CODESPACE=1
  export DOTFILES_CONTAINER=1
fi

# Detect VS Code devcontainer (Remote - Containers sets this)
if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${REMOTE_CONTAINERS_IPC:-}" ]; then
  export DOTFILES_DEVCONTAINER=1
  export DOTFILES_CONTAINER=1
fi
