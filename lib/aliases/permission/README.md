# 🅿🅴🆁🅼🅸🆂🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂

<!-- markdownlint-disable MD033 MD041 -->

<img src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
alt="dotfiles logo" width="261" align="right" />

<!-- markdownlint-enable MD033 MD041 -->

This code provides a set of aliases for file permissions.

## Aliases

- `000` (chmod a-rwx) sets permissions so that, (U)ser / owner can't
  read, can't write and can't execute. (G)roup can't read, can't write
  and can't execute. (O)thers can't read, can't write and can't execute.
- `400` (chmod a-rw) sets permissions so that, (U)ser / owner can't
  read, can't write and can execute. (G)roup can't read, can't write and
  can execute. (O)thers can't read, can't write and can execute.
- `444` (chmod a-r) sets permissions so that, (U)ser / owner can't read,
  can't write and can execute. (G)roup can't read, can't write and can
  execute. (O)thers can't read, can't write and can execute.
- `600` (chmod a+rwx,u-x,g-rwx,o-rwx) sets permissions so that, (U)ser /
  owner can read, can write and can't execute. (G)roup can't read, can't
  write and can't execute. (O)thers can't read, can't write and can't
  execute.
- `644` (chmod a+rwx,u-x,g-wx,o-wx) sets permissions so that, (U)ser /
  owner can read, can write and can't execute. (G)roup can read, can't
  write and can't execute. (O)thers can read, can't write and can't
  execute.
- `666` (chmod a+rwx,u-x,g-x,o-x) sets permissions so that, (U)ser /
  owner can read, can write and can't execute. (G)roup can read, can
  write and can't execute. (O)thers can read, can write and can't
  execute.
- `755` (chmod a+rwx,g-w,o-w) sets permissions so that, (U)ser / owner
  can read, can write and can execute. (G)roup can read, can't write and
  can execute. (O)thers can read, can't write and can execute.
- `764` (chmod a+rwx,g-x,o-wx) sets permissions so that, (U)ser / owner
  can read, can write and can execute. (G)roup can read, can write and
  can't execute. (O)thers can read, can't write and can't execute.
- `777` (chmod a+rwx) sets permissions so that, (U)ser / owner can read,
  can write and can execute. (G)roup can read, can write and can
  execute. (O)thers can read, can write and can execute.
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
