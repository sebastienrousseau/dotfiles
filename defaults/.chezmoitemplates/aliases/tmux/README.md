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
| `tmr` | `tmux source-file "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"` | Reload the deployed configuration. |
| `tmls` | `tmux list-windows` | List windows. |
| `tmlp` | `tmux list-panes` | List panes. |
| `tmi` | `tmux info` | Show tmux info. |

A new server reads `~/.config/tmux/tmux.conf` by itself; it is deployed from `defaults/dot_config/tmux/tmux.conf.tmpl`.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
