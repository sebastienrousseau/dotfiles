# shellcheck shell=bash

# Standard system paths
export PATH=/usr/bin:"${PATH}"
export PATH=/bin:"${PATH}"
export PATH=/sbin:"${PATH}"

# XDG Base Directory Standards
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

# Homebrew paths (macOS only)
if [[ "$OSTYPE" == darwin* ]]; then
  [[ -d /opt/homebrew/bin ]] && export PATH=/opt/homebrew/bin:"${PATH}"
  [[ -d /opt/homebrew/sbin ]] && export PATH=/opt/homebrew/sbin:"${PATH}"

  # Add Ruby homebrew binaries to PATH (check version with: ruby --version)
  if [[ -x /opt/homebrew/opt/ruby/bin/ruby ]]; then
    export PATH="/opt/homebrew/opt/ruby/bin/:${PATH}"
  fi
fi

# Linux Homebrew/Linuxbrew support
if [[ "$OSTYPE" == linux* ]] && [[ -d /home/linuxbrew/.linuxbrew ]]; then
  export PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"
fi

# Add Ruby gem binaries to PATH (cross-platform)
[[ -d "${HOME}/.gem/ruby/bin" ]] && export PATH="${HOME}/.gem/ruby/bin:${PATH}"
