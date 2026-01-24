#!/bin/bash
set -e

# Cleanup any partial downloads
rm -f nvim-linux-x86_64.tar.gz nvim-linux-x86_64.tar.gz.sha256sum nvim-linux64.tar.gz

sha256_file() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "sha256sum or shasum is required for verified downloads."
    exit 1
  fi
}

echo "Downloading Nightly (v0.11) [Correct URL]..."
curl -fLo nvim-linux-x86_64.tar.gz https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz
curl -fLo nvim-linux-x86_64.tar.gz.sha256sum https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz.sha256sum

expected="$(awk -v f="nvim-linux-x86_64.tar.gz" '$2==f {print $1}' nvim-linux-x86_64.tar.gz.sha256sum)"
if [ -z "$expected" ]; then
  expected="$(awk '{print $1}' nvim-linux-x86_64.tar.gz.sha256sum | head -n1)"
fi
actual="$(sha256_file nvim-linux-x86_64.tar.gz)"
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
  echo "Checksum verification failed for nvim-linux-x86_64.tar.gz."
  exit 1
fi

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
