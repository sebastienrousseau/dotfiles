# tmux Aliases

Manage tmux aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `tmux.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `tmux` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `tm` | function | Run `tmux` with any arguments; with no server running, start a session and attach. |
| `tma` | `tmux attach-session` | Attach to last session. |
| `tmat` | `tmux attach-session -t` | Attach to specific session. |
| `tmks` | `tmux kill-session -a` | Kill all sessions except current. |
| `tmka` | `tmux kill-server` | Kill all sessions (server) |
| `tml` | `tmux list-sessions` | List all sessions. |
| `tmn` | `tmux new-session` | New unnamed session. |
| `tms` | `tmux new-session -s` | New named session. |
| `tmr` | `tmux source ~/.dotfiles/lib/configurations/tmux/tmux` | Meant to reload the configuration, but it sources `~/.dotfiles/lib/configurations/tmux/tmux`, which does not exist; the deployed configuration is `~/.config/tmux/tmux.conf`. |
| `tmls` | `tmux list-windows` | List windows. |
| `tmlp` | `tmux list-panes` | List panes. |
| `tmi` | `tmux info` | Show tmux info. |

`tm` has the same problem as `tmr` when it starts a new server: it sources the missing `~/.dotfiles/lib/configurations/tmux/tmux`. tmux itself reads `~/.config/tmux/tmux.conf`, deployed from `defaults/dot_config/tmux/tmux.conf.tmpl`.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
