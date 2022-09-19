#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Editor configuration.

if ! [ "$(command -v vim)" ]; then
  export VISUAL="vi"
else
  export VISUAL="vim"
fi

export EDITOR=$VISUAL
export GIT_EDITOR=$VISUAL
export SVN_EDITOR=$VISUAL
export SUDO_EDITOR=$VISUAL
