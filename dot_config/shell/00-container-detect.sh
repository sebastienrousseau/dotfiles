#!/usr/bin/env bash
set -euo pipefail

# 00-container-detect.sh: Detect container environments
# Sets environment flags so downstream configs can adapt behaviour
# (e.g. simpler prompts, skip host-only tooling).

# Detect container environment
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qsm1 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null; then
  export DOTFILES_CONTAINER=1
fi

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
