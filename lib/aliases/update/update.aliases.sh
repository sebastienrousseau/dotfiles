#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.464) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🆄🅿🅳🅰🆃🅴 🅰🅻🅸🅰🆂🅴🆂
if [[ "$(uname || true)" = "Darwin" ]]; then
    alias upd='
        sudo softwareupdate -i -a;
        pnpm up;
        rustup update stable;
        if [[ "$(command -v brew cu)" ]]; then
            brew cu -ayi;
        else
            brew tap buo/cask-upgrade;
        fi;
        brew doctor;
        brew update;
        brew upgrade;
        brew cleanup;
        mas upgrade;
        sudo gem update;
        sudo gem cleanup;
    '
elif [[ "$(uname || true)" = "Linux" ]]; then
    alias open="xdg-open >/dev/null 2>&1"     # open: Open a file or URL in the user's preferred application.
    alias pbcopy='xsel --clipboard --input'   # pbcopy: Copy to clipboard.
    alias pbpaste='xsel --clipboard --output' # pbpaste: Paste from clipboard.
    alias upd='
        sudo apt update;
        sudo apt upgrade -y;
        pnpm up;
        rustup update stable;
        sudo gem update;
        sudo gem cleanup;
    '
fi
