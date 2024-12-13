#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🆄🅿🅳🅰🆃🅴 🅰🅻🅸🅰🆂🅴🆂
os_name="$(uname)"

if [[ "${os_name}" = "Darwin" ]]; then
  alias upd="
        echo \"❯ Updating \${os_name}...\";
        sudo softwareupdate -i -a;
        echo '❯ Updating Homebrew...';
        brew update && brew upgrade;
        echo '❯ Updating pnpm packages...';
        pnpm up;
        echo '❯ Updating Rust stable toolchain...';
        rustup update stable;
        echo '❯ Updating Homebrew Casks...';
        brew cu -ayi || (brew tap buo/cask-upgrade && brew cu -ayi);
        echo '❯ Cleaning up Homebrew...';
        brew cleanup && brew doctor;
        echo '❯ Updating Mac App Store apps...';
        mas upgrade;
        echo '❯ Updating Ruby gems...';
        sudo gem update && sudo gem cleanup;
        echo '❯ Updating Python packages...';
        pip install --upgrade --user pip setuptools wheel;
        update_outdated_pip_packages();
        echo '❯ Updating Node.js packages...';
        npm update -g;
        echo '❯ Update complete!';
    "
elif [[ "${os_name}" = "Linux" ]]; then
  # Open a file or URL in the user's preferred application.
  alias open="xdg-open >/dev/null 2>&1"

  # Copy to clipboard.
  alias pbcopy='xsel --clipboard --input'

  # Paste from clipboard.
  alias pbpaste='xsel --clipboard --output'
  alias upd="
        echo \"❯ Updating \${os_name}...\";
        sudo apt update && sudo apt upgrade -y;
        echo '❯ Cleaning up package cache...';
        sudo apt autoremove -y && sudo apt clean;
        echo '❯ Updating pnpm packages...';
        pnpm up;
        echo '❯ Updating Rust stable toolchain...';
        rustup update stable;
        echo '❯ Updating Ruby gems...';
        sudo gem update && sudo gem cleanup;
        echo '❯ Updating Python packages...';
        pip install --upgrade --user pip setuptools wheel;
        update_outdated_pip_packages();
        echo '❯ Updating Node.js packages...';
        npm update -g;
        echo '❯ Update complete!';
    "
fi

function update_outdated_pip_packages() {
  pip list --user --outdated --format=columns |
    awk 'NR>2 {print $1}' |
    xargs -I{} pip install -U --user "{}" || true
}
