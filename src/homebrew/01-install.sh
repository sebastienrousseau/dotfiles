#!/bin/sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Homebrew installer

# Check for Homebrew presence
if test ! "$(which brew)"; then
  echo "🍺 Installing Homebrew for you."

  # Install Homebrew for each OS type
  os_type=$(uname)
  if [ "$os_type" = "Darwin" ]; then
    # Install Homebrew for macOS
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  elif [ "$os_type" = "Linux" ]; then
    # Install Homebrew for Linux
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)"
  elif [ "$os_type" = "Windows" ]; then
    # Install Homebrew for macOS
    echo "🍺 Homebrew is not supported on Windows, please use Windows Subsystem for Linux (WSL)."
  else
    echo "🍺  Looks like Homebrew is already installed!"
  fi
fi

exit 0
