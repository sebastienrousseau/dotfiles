#!/bin/bash
set -e

# Cleanup any partial downloads
rm -f nvim-linux-x86_64.tar.gz nvim-linux64.tar.gz

echo "Downloading Nightly (v0.11) [Correct URL]..."
curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz

echo "Removing old version..."
sudo rm -rf /opt/nvim-linux64 /opt/nvim-linux-x86_64

echo "Extracting..."
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

echo "Linking binary..."
# Note: The folder name changed to nvim-linux-x86_64
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim "$HOME/.local/bin/nvim"

echo "Done! Verifying..."
/usr/local/bin/nvim --version
