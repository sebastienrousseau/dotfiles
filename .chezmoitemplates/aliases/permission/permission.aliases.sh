# shellcheck shell=bash

if command -v chmod &>/dev/null; then

  # Set permissions to no read, write, or execute for user, group, and
  # others.
  alias 000='chmod -R 000'

  # Set permissions to no read or write, but allow execute for user
  # only.
  alias 400='chmod -R 400'

  # Set permissions to no write or execute, but allow read for all.
  alias 444='chmod -R 444'

  # Set permissions to read and write for user only.
  alias 600='chmod -R 600'

  # Set permissions to read for all, but write only for user.
  alias 644='chmod -R 644'

  # Set permissions to read and write for all. (CAUTION: world-writable)
  alias 666='echo "WARNING: 666 makes files world-writable" && chmod -R 666'

  # Set permissions to read, write, and execute for user, but only read
  # and execute for group and others.
  alias 755='chmod -R 755'

  # Set permissions to read and write for user and group, but only read
  #  for others.
  alias 764='chmod -R 764'

  # Set permissions to read, write, and execute for all. (CAUTION: world-writable+executable)
  alias 777='echo "WARNING: 777 makes files world-writable and executable" && chmod -R 777'

  # Change group ownership of files or directories.
  alias chgrp='chgrp -v'

  # Change group ownership of files or directories recursively.
  alias chgrpr='chgrp -Rv'

  # Change group ownership of files or directories recursively to the
  #  current user.
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
