#!/bin/bash
set -e

echo "Removing old version..."
rm -rf /opt/nvim-linux64

echo "Extracting new version..."
# Ensure we use the absolute path to the downloaded file
tar -C /opt -xzf /home/seb/nvim-linux64.tar.gz

echo "Linking binary..."
ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim

echo "Done! Verifying..."
/usr/local/bin/nvim --version
