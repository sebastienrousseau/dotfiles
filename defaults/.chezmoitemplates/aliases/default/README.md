# Default Aliases

General-purpose shell aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `default.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `da` | `date "+%Y-%m-%d %A %T %Z"` | Display the current date and time. |
| `r` | `reload` | Reload the shell. |
| `t` | `tail -f` | Prints the last 10 lines of a text or log file, and then waits for new additions to the file to print it in real time. |
| `wk` | `date +%V` | Show the current week number. |
| `:q` | `quit` | Runs `quit`, which is `exit`. |
| `q` | `quit` | Runs `quit`, which is `exit`. |
| `quit` | `exit` | Shortcut for the `exit` command. |
| `halt` | `sudo shutdown -h now` | Shutdown the system (portable form). |
| `history` | `fc -il 1` | Show history with timestamps. Only in zsh. |
| `poweroff` | `sudo shutdown -h now` | Poweroff the system (portable syntax). |
| `reboot` | `sudo shutdown -r now` | Reboot the system (portable syntax). |
| `ipinfo` | `ip -br addr` | Only when `ip` is on PATH; on macOS without `ip`, it is `ipconfig getpacket en0`. |
| `ping` | `ping -c 5` | Limit Ping to 5 ECHO_REQUEST packets. |
| `clearasl` | `clear_asl_logs` | Clear ASL logs (macOS) - requires confirmation. |
| `ctf` | `echo $(ls -1 \| wc -l)` | Count the number of files in the current directory. |
| `qfind` | `find . -name <pattern>` | Quickly search for file. |
| `reload` | `exec $SHELL -l` | Reload the shell. |
| `pbcopy` | function | Clipboard copy on Linux when no `pbcopy` exists: uses `wl-copy`, `xclip`, `xsel` or `clip.exe`, the first one found. |
| `pbpaste` | function | Clipboard paste on Linux when no `pbpaste` exists: uses `wl-paste`, `xclip`, `xsel` or PowerShell, matching `pbcopy`. |

Other common one-letter names live elsewhere: `c` in the clear aliases, `p`, `h`, `path` and `top` in the system aliases.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
