#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

# 🆃🅼🆄🆇 🅰🅻🅸🅰🆂🅴🆂

if command -v 'tmux' >/dev/null; then

  # Start tmux.
  alias tm='tmux'

  # Attach to a tmux session.
  alias tma="tmux attach-session"

  # Attach to a tmux session with name.
  alias tmat="tmux attach-session -t"

  # Kill all tmux sessions.
  alias tmks='tmux kill-session -a'

  # List tmux sessions.
  alias tml='tmux list-sessions'

  # Start a new tmux session.
  alias tmn="tmux new-session"

  # Start a new tmux session with name.
  alias tmns="tmux new -s"

  # Start a new tmux session.
  alias tms='tmux new-session -s'

fi
