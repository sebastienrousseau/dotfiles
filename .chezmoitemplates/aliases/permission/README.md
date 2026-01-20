# Permission Aliases

Manage Permission aliases. Part of the **Universal Dotfiles** configuration.

## 📖 Description
These aliases are defined in `permission.aliases.sh` and are automatically loaded by `chezmoi`.

## ⚡ Aliases

alt="dotfiles logo"
  width="66"

This code provides a set of aliases for file permissions.
- `000` Set permissions to no read, write, or execute for user, group,
  and others.
- `400` Set permissions to no read or write, but allow execute for user
  only.
- `444` Set permissions to no write or execute, but allow read for all.
- `600` Set permissions to read and write for user only.
- `644` Set permissions to read for all, but write only for user.
- `666` Set permissions to read and write for all.
- `755` Set permissions to read, write, and execute for user, but only
  read and execute for group and others.
- `764` Set permissions to read and write for user and group, but only
  read for others.
- `777` Set permissions to read, write, and execute for all.
- `chgrp` Change group ownership of files or directories.
- `chgrpr` Change group ownership of files or directories recursively.
- `chgrpu` Change group ownership of files or directories recursively to
  the current user.
- `chmod` Change file mode bits.
- `chmodr` Change file mode bits recursively.
- `chmodu` Change file mode bits recursively to the current user.
- `chmox` Make a file executable.
- `chown` Change file owner and group.
- `chownr` Change file owner and group recursively.
- `chownu` Change file owner and group recursively to the current user.
