#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🆃🅼🆄🆇 🅰🅻🅸🅰🆂🅴🆂
if command -v 'tmux' >/dev/null; then
  alias tm='tmux'                     # tm: Start tmux.
  alias tma="tmux attach-session"     # tma: Attach to a tmux session.
  alias tmat="tmux attach-session -t" # tmat: Attach to a tmux session with name.
  alias tmks='tmux kill-session -a'   # tmks: Kill all tmux sessions.
  alias tml='tmux list-sessions'      # tml: List tmux sessions.
  alias tmn="tmux new-session"        # tmn: Start a new tmux session.
  alias tmns="tmux new -s"            # tmns: Start a new tmux session with name.
  alias tms='tmux new-session -s'     # tms: Start a new tmux session.
fi
