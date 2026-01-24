#!/bin/bash
set -e

sudo_cmd=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null; then
    sudo_cmd="sudo"
  else
    echo "This script requires root privileges or sudo."
    exit 1
  fi
fi

echo "Removing old version..."
$sudo_cmd rm -rf /opt/nvim-linux64

echo "Extracting new version..."
# Ensure we use the absolute path to the downloaded file
$sudo_cmd tar -C /opt -xzf "$HOME/nvim-linux64.tar.gz"

echo "Linking binary..."
$sudo_cmd ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim

echo "Done! Verifying..."
/usr/local/bin/nvim --version
