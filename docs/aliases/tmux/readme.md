# Tmux core aliases

This `tmux.aliases.zsh` file creates helpful shortcut aliases for many
commonly used [tmux](https://github.com/tmux/tmux/wiki) commands.

## Tmux development aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| tm |`tmux` | Start tmux. |
| tma |`tmux attach-session` | Attach to a tmux session. |
| tmat |`tmux attach-session -t` | Attach to a tmux session with name. |
| tmks |`tmux kill-session -a` | Kill all tmux sessions. |
| tml |`tmux list-sessions` | List tmux sessions. |
| tmn |`tmux new-session` | Start a new tmux session. |
| tmns |`tmux new -s` | Start a new tmux session with name. |
| tms |`tmux new-session -s` | Start a new tmux session. |
