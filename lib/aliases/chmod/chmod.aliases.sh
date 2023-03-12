#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets aliases for the `chmod` command.
# License: MIT
# Script: chmod.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅲🅷🅼🅾🅳 🅰🅻🅸🅰🆂🅴🆂
if command -v 'chmod' >/dev/null; then

  # Shortcuts to change permissions
  alias 000='chmod -R 000' # 000: (chmod a-rwx) sets permissions so that, (U)ser / owner can't read, can't write and can't execute. (G)roup can't read, can't write and can't execute. (O)thers can't read, can't write and can't execute.
  alias 400='chmod -R 400' # 400: (chmod a-rw) sets permissions so that, (U)ser / owner can't read, can't write and can execute. (G)roup can't read, can't write and can execute. (O)thers can't read, can't write and can execute.
  alias 444='chmod -R 444' # 444: (chmod a-r) sets permissions so that, (U)ser / owner can't read, can't write and can execute. (G)roup can't read, can't write and can execute. (O)thers can't read, can't write and can execute.
  alias 600='chmod -R 600' # 600: (chmod a+rwx,u-x,g-rwx,o-rwx) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can't read, can't write and can't execute. (O)thers can't read, can't write and can't execute.
  alias 644='chmod -R 644' # 644: (chmod a+rwx,u-x,g-wx,o-wx) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can read, can't write and can't execute. (O)thers can read, can't write and can't execute.
  alias 666='chmod -R 666' # 666: (chmod a+rwx,u-x,g-x,o-x) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can read, can write and can't execute. (O)thers can read, can write and can't execute.
  alias 755='chmod -R 755' # 755: (chmod a+rwx,g-w,o-w) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can't write and can execute. (O)thers can read, can't write and can execute.
  alias 764='chmod -R 764' # 764: (chmod a+rwx,g-x,o-wx) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can write and can't execute. (O)thers can read, can't write and can't execute.
  alias 777='chmod -R 777' # 777: (chmod a+rwx) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can write and can execute. (O)thers can read, can write and can execute.

  # Shortcuts to change ownership
  alias chgrp='chgrp -v'           # chgrp: Change group ownership of files or directories.
  alias chgrpr='chgrp -Rv'         # chgrpr: Change group ownership of files or directories recursively.
  alias chgrpu='chgrp -Rv ${USER}' # chgrpu: Change group ownership of files or directories recursively to the current user.
  alias chmod='chmod -v'           # chmod: Change file mode bits.
  alias chmodr='chmod -Rv'         # chmodr: Change file mode bits recursively.
  alias chmodu='chmod -Rv u+rwX'   # chmodu: Change file mode bits recursively to the current user.
  alias chmox='chmod +x'           # chmox: Make a file executable.
  alias chown='chown -v'           # chown: Change file owner and group.
  alias chownr='chown -Rv'         # chownr: Change file owner and group recursively.
  alias chownu='chown -Rv ${USER}' # chownu: Change file owner and group recursively to the current user.

  # Shortcuts to set permissions for specific file types
  alias 755d='find . -type d -exec chmod 755 {} \;' # 755d: Set permissions of all directories to rwxr-xr-x.
  alias 644f='find . -type f -exec chmod 644 {} \;' # 644f: Set permissions of all files to rw-r--r--.

  # Shortcuts to set permissions for specific user types
  alias u+x='chmod u+x' # u+x: Add execute permission for the owner of the file.
  alias u-x='chmod u-x' # u-x: Remove execute permission for the owner of the file.
  alias u+w='chmod u+w' # u+w: Add write permission for the owner of the file.
  alias u-w='chmod u-w' # u-w: Remove write permission for the owner of the file.
  alias u+r='chmod u+r' # u+r: Add read permission for the owner of the file.
  alias u-r='chmod u-r' # u-r: Remove read permission for the owner of the file.

  alias g+x='chmod g+x' # g+x: Add execute permission for the group owner of the file.
  alias g-x='chmod g-x' # g-x: Remove execute permission for the group owner of the file.
  alias g+w='chmod g+w' # g+w: Add write permission for the group owner of the file.
  alias g-w='chmod g-w' # g-w: Remove write permission for the group owner of the file.
  alias g+r='chmod g+r' # g+r: Add read permission for the group owner of the file.
  alias g-r='chmod g-r' # g-r: Remove read permission for the group owner of the file.

  alias o+x='chmod o+x' # o+x: Add execute permission for others.
  alias o-x='chmod o-x' # o-x: Remove execute permission for others.
  alias o+w='chmod o+w' # o+w: Add write permission for others.
  alias o-w='chmod o-w' # o-w: Remove write permission for others.
  alias o+r='chmod o+r' # o+r: Add read permission for others.
  alias o-r='chmod o-r' # o-r: Remove read permission for others.

  # Shortcuts to set permissions based on octal notation
  alias 000='chmod 000' # 000: Set permissions to ----------
  alias 400='chmod 400' # 400: Set permissions to r--------
  alias 444='chmod 444' # 444: Set permissions to r--r--r--
  alias 600='chmod 600' # 600: Set permissions to rw-------
  alias 644='chmod 644' # 644: Set permissions to rw-r--r--.
  alias 664='chmod 664' # 664: Set permissions to rw-rw-r--.
  alias 755='chmod 755' # 755: Set permissions to rwxr-xr-x.
  alias 775='chmod 775' # 775: Set permissions to rwxrwxr-x.
  alias 777='chmod 777' # 777: Set permissions to rwxrwxrwx.

fi
