# System Aliases

Runtime and system helpers: shell, process, network and nmap shortcuts. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `system.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category). Disabled by `aliases.buckets.system = false` in the chezmoi data.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `h` | `history` | Show the shell history. |
| `p` | `pwd` | Replaces `p='podman'` from `modern.aliases.sh`, which loads earlier. |
| `path` | `echo ${PATH//:/\\n}` | Print each `PATH` entry on its own line. |
| `wth` | `curl -s "wttr.in/?format=3"` | Show the weather for your location. |
| `d` | `dot` | Only when `dot` is on PATH. The `dig` and `docker` aliases of the same name apply only without it. |
| `i` | `epoch` | Only when `epoch` is on PATH. |
| `pid` | `ps -f` | Only when `ps` is on PATH. |
| `ps` | `ps -ef` | Only when `ps` is on PATH. |
| `psa` | `ps aux` | Only when `ps` is on PATH. |
| `nls` | `sudo lsof -i -P \| grep LISTEN` | Only when `lsof` is on PATH. |
| `op` | `sudo lsof -i -P` | Only when `lsof` is on PATH. |
| `ports` | `ss -tulan` | `ss -tulan`, or `netstat -tulan` when `ss` is not on PATH. |
| `top` | `sudo btop` |  |
| `wip` | `dig +short myip.opendns.com @resolver1.opendns.com` | Only when `dig` is on PATH. |
| `update-fonts` | `if command -v fc-cache >/dev/null; then fc-cache -fv; else echo "fc-cache not found (is fontconfig installed?)"; fi` | Refresh the font cache with `fc-cache`, or say it is missing. |
| `nma` | `sudo nmap -A` | Only when `nmap` is on PATH. |
| `nmall` | `nmap -A -T4 -p-` | Only when `nmap` is on PATH. |
| `nmfast` | `nmap -F` | Only when `nmap` is on PATH. |
| `nmo` | `nmap -O` | Only when `nmap` is on PATH. |
| `nmp` | `nmap -Pn` | Only when `nmap` is on PATH. |
| `nmping` | `nmap -sn` | Only when `nmap` is on PATH. |
| `nms` | `nmap -sS` | Only when `nmap` is on PATH. |
| `nmv` | `nmap -sV` | Only when `nmap` is on PATH. |
| `nmvuln` | `nmap --script vuln` | Only when `nmap` is on PATH. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
