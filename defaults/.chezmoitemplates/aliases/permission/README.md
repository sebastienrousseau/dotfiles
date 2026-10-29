# Permission Aliases

Manage numeric permission, ownership and group aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `permission.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Every definition below exists only when `chmod` is on PATH.

The numeric aliases all apply the mode recursively (`chmod -R`).

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `000` | `chmod -R 000` | No access for anyone. |
| `400` | `chmod -R 400` | Read-only for the owner; nothing for group and others. |
| `444` | `chmod -R 444` | Read-only for everyone. |
| `600` | `chmod -R 600` | Read and write for the owner only. |
| `644` | `chmod -R 644` | Read and write for the owner, read for group and others. |
| `755` | `chmod -R 755` | Full access for the owner, read and execute for group and others. |
| `764` | `chmod -R 764` | Full access for the owner, read and write for the group, read for others. |
| `chgrp` | `chgrp -v` | Change group ownership of files or directories. |
| `chgrpr` | `chgrp -Rv` | Change group ownership of files or directories recursively. |
| `chgrpu` | `chgrp -Rv ${USER}` | Change group ownership of files or directories recursively to the current user. |
| `chmod` | `chmod -v` | Change file mode bits. |
| `chmodr` | `chmod -Rv` | Change file mode bits recursively. |
| `chmodu` | `chmod -Rv u+rwX` | Change file mode bits recursively to the current user. |
| `chmox` | `chmod +x` | Make a file executable. |
| `chown` | `chown -v` | Change file owner and group. |
| `chownr` | `chown -Rv` | Change file owner and group recursively. |
| `chownu` | `chown -Rv ${USER}` | Change file owner and group recursively to the current user. |

The file also carries `666` and `777` aliases, commented out.

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
