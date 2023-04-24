#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅿🅴🆁🅼🅸🆂🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂

if command -v chmod &>/dev/null; then

  # (chmod a-rwx) sets permissions so that, (U)ser / owner can't read,
  # can't write and can't execute. (G)roup can't read, can't write and
  # can't execute. (O)thers can't read, can't write and can't execute.
  alias 000='chmod -R 000'

  # (chmod a-rw) sets permissions so that, (U)ser / owner can't read,
  # can't write and can execute. (G)roup can't read, can't write and can
  # execute. (O)thers can't read, can't write and can execute.
  alias 400='chmod -R 400'

  # (chmod a-r) sets permissions so that, (U)ser / owner can't read,
  # can't write and can execute. (G)roup can't read, can't write and can
  # execute. (O)thers can't read, can't write and can execute.
  alias 444='chmod -R 444'

  # (chmod a+rwx,u-x,g-rwx,o-rwx) sets permissions so that, (U)ser /
  # owner can read, can write and can't execute. (G)roup can't read,
  # can't write and can't execute. (O)thers can't read, can't write and
  # can't execute.
  alias 600='chmod -R 600'

  # (chmod a+rwx,u-x,g-wx,o-wx) sets permissions so that, (U)ser /
  # owner can read, can write and can't execute. (G)roup can read,
  # can't write and can't execute. (O)thers can read, can't write and
  # can't execute.
  alias 644='chmod -R 644'

  # (chmod a+rwx,u-x,g-x,o-x) sets permissions so that, (U)ser / owner
  # can read, can write and can't execute. (G)roup can read, can write
  # and can't execute. (O)thers can read, can write and can't execute.
  alias 666='chmod -R 666'

  # (chmod a+rwx,g-w,o-w) sets permissions so that, (U)ser / owner can
  # read, can write and can execute. (G)roup can read, can't write and
  # can execute. (O)thers can read, can't write and can execute.
  alias 755='chmod -R 755'

  # (chmod a+rwx,g-x,o-wx) sets permissions so that, (U)ser / owner
  # can read, can write and can execute. (G)roup can read, can write and
  # can't execute. (O)thers can read, can't write and can't execute.
  alias 764='chmod -R 764'

  # (chmod a+rwx) sets permissions so that, (U)ser / owner can read,
  # can write and can execute. (G)roup can read, can write and can
  # execute. (O)thers can read, can write and can execute.
  alias 777='chmod -R 777'

  # Change group ownership of files or directories.
  alias chgrp='chgrp -v'

  # Change group ownership of files or directories recursively.
  alias chgrpr='chgrp -Rv'

  # Change group ownership of files or directories recursively to the
  # current user.
  alias chgrpu='chgrp -Rv ${USER}'

  # Change file mode bits.
  alias chmod='chmod -v'

  # Change file mode bits recursively.
  alias chmodr='chmod -Rv'

  # Change file mode bits recursively to the current user.
  alias chmodu='chmod -Rv u+rwX'

  # Make a file executable.
  alias chmox='chmod +x'

  # Change file owner and group.
  alias chown='chown -v'

  # Change file owner and group recursively.
  alias chownr='chown -Rv'

  # Change file owner and group recursively to the current user.
  alias chownu='chown -Rv ${USER}'
fi
