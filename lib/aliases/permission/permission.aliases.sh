#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅿🅴🆁🅼🅸🆂🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂
if command -v chmod &>/dev/null; then
  alias 000='chmod -R 000'         # 000: (chmod a-rwx) sets permissions so that, (U)ser / owner can't read, can't write and can't execute. (G)roup can't read, can't write and can't execute. (O)thers can't read, can't write and can't execute.
  alias 400='chmod -R 400'         # 400: (chmod a-rw) sets permissions so that, (U)ser / owner can't read, can't write and can execute. (G)roup can't read, can't write and can execute. (O)thers can't read, can't write and can execute.
  alias 444='chmod -R 444'         # 444: (chmod a-r) sets permissions so that, (U)ser / owner can't read, can't write and can execute. (G)roup can't read, can't write and can execute. (O)thers can't read, can't write and can execute.
  alias 600='chmod -R 600'         # 600: (chmod a+rwx,u-x,g-rwx,o-rwx) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can't read, can't write and can't execute. (O)thers can't read, can't write and can't execute.
  alias 644='chmod -R 644'         # 644: (chmod a+rwx,u-x,g-wx,o-wx) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can read, can't write and can't execute. (O)thers can read, can't write and can't execute.
  alias 666='chmod -R 666'         # 666: (chmod a+rwx,u-x,g-x,o-x) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can read, can write and can't execute. (O)thers can read, can write and can't execute.
  alias 755='chmod -R 755'         # 755: (chmod a+rwx,g-w,o-w) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can't write and can execute. (O)thers can read, can't write and can execute.
  alias 764='chmod -R 764'         # 764: (chmod a+rwx,g-x,o-wx) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can write and can't execute. (O)thers can read, can't write and can't execute.
  alias 777='chmod -R 777'         # 777: (chmod a+rwx) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can write and can execute. (O)thers can read, can write and can execute.
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
fi
