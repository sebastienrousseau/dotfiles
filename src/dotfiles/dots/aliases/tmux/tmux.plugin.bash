# shellcheck shell=bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
cite 'about-alias'
about-alias 'Tmux terminal multiplexer'

alias tm='tmux'                   # tm: Start tmux.
alias tma='tmux attach'           # tma: Attach to a tmux session.
alias tma0='tmux attach -t 0'     # tma0: Attach to a tmux session 0.
alias tma1='tmux attach -t 1'     # tma1: Attach to a tmux session 1.
alias tma2='tmux attach -t 2'     # tma2: Attach to a tmux session 2.
alias tmk='tmux kill-session -t'  # tmk: Kill a tmux session.
alias tml='tmux list-sessions'    # tml: List tmux sessions.
