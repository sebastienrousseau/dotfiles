#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

cmd_vim=$(command -v vim)
if [[ -z ${cmd_vim} ]]; then
  export VISUAL="vi"
else
  export VISUAL="vim"
fi

export EDITOR=${VISUAL}
export GIT_EDITOR=${VISUAL}
export SVN_EDITOR=${VISUAL}
export SUDO_EDITOR=${VISUAL}
