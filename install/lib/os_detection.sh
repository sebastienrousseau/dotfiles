#!/usr/bin/env bash
# OS Detection Library
# Provides consistent OS and architecture detection across the installer

# Detect operating system and set target_os variable
# Sets: OS, ARCH, target_os
detect_os() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  target_os="unknown"

  case "$OS" in
    Darwin)
      target_os="macos"
      ;;
    Linux)
      if [ -f /proc/version ] && grep -qi 'microsoft\|WSL' /proc/version; then
        target_os="wsl2"
      elif [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
          ubuntu|debian|pop|linuxmint|elementary)
            target_os="debian"
            ;;
          fedora|rhel|centos|rocky|alma)
            target_os="fedora"
            ;;
          arch|manjaro|endeavouros)
            target_os="arch"
            ;;
          *)
            target_os="linux"
            ;;
        esac
      else
        target_os="linux"
      fi
      ;;
  esac

  export OS ARCH target_os
}

# Check if running on macOS
is_macos() {
  [ "$target_os" = "macos" ]
}

# Check if running on Linux (any variant)
is_linux() {
  [ "$OS" = "Linux" ]
}

# Check if running in WSL2
is_wsl() {
  [ "$target_os" = "wsl2" ]
}

# Check if running on Debian-based system
is_debian() {
  [ "$target_os" = "debian" ] || [ "$target_os" = "wsl2" ]
}

# Check if running on Fedora-based system
is_fedora() {
  [ "$target_os" = "fedora" ]
}

# Check if running on Arch-based system
is_arch() {
  [ "$target_os" = "arch" ]
}

# Print detected OS information
print_os_info() {
  echo "   OS: $OS"
  echo "   Arch: $ARCH"
  echo "   Target: $target_os"
}
