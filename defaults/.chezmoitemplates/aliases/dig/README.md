# Dig Aliases

Manage DNS lookup aliases built on `dig`. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `dig.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `network`. Every definition below exists only when `dig` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `d` | `dig` | Only when `d` is not already an alias, so it is skipped whenever `system.aliases.sh` set `d='dot'`. |
| `d4` | `dig +short -4` | Perform a DNS lookup for an IPv4 address. |
| `d6` | `dig +short -6` | Perform a DNS lookup for an IPv6 address. |
| `dga` | `dig +all ANY` | Perform a DNS lookup for all records. |
| `dgs` | `dig +short` | Perform a DNS lookup for a short answer. |
| `digg` | `dig @8.8.8.8 +nocmd any +multiline +noall +answer` | Dig with Google's DNS. |
| `ip4` | `dig +short myip.opendns.com @resolver1.opendns.com -4` | Get your public IPv4 address. |
| `ip6` | `dig -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.` | Get your public IPv6 address. |
| `ips` | `ip4; ip6` | Get your public IPv4 and IPv6 addresses. |
| `wip` | `dig +short myip.opendns.com @resolver1.opendns.com` | Get your public IP address. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
