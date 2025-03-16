#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🆃🅼🆄🆇 🅰🅻🅸🅰🆂🅴🆂

if command -v 'tmux' >/dev/null; then
  # Basic commands
  tm() {
    if ! tmux has-session 2>/dev/null; then
      # Start tmux and immediately source the config
      tmux new-session -d \; source-file ~/.dotfiles/lib/configurations/tmux/tmux
      tmux attach
    else
      tmux "$@"
    fi
  } # Start tmux

  alias tma='tmux attach-session'     # Attach to last session
  alias tmat='tmux attach-session -t' # Attach to specific session

  # Session management
  alias tmks='tmux kill-session -a'   # Kill all sessions except current
  alias tmka='tmux kill-server'       # Kill all sessions (server)
  alias tml='tmux list-sessions'      # List all sessions

  # Creating sessions
  alias tmn='tmux new-session'        # New unnamed session
  alias tms='tmux new-session -s'     # New named session

  # Configuration
  alias tmr='tmux source ~/.dotfiles/lib/configurations/tmux/tmux' # Reload config

  # Windows and panes
  alias tmls='tmux list-windows'      # List windows
  alias tmlp='tmux list-panes'        # List panes

  # Status information
  alias tmi='tmux info'               # Show tmux info
fi
