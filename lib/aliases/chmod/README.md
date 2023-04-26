# CHMOD Aliases

These aliases provide shortcuts for the chmod command to help you
quickly change the permissions of files and directories. To use them,
add the following lines to your .bashrc or .bash_profile file.

## 🅰🅻🅸🅰🆂🅴🆂

### Change permissions

- `000`: (chmod a-rwx) sets permissions so that, (U)ser / owner can't read, can't write and can't execute. (G)roup can't read, can't write and can't execute. (O)thers can't read, can't write and can't execute.
- `400`: (chmod a-rw) sets permissions so that, (U)ser / owner can't read, can't write and can execute. (G)roup can't read, can't write and can execute. (O)thers can't read, can't write and can execute.
- `444`: (chmod a-r) sets permissions so that, (U)ser / owner can't read, can't write and can execute. (G)roup can't read, can't write and can execute. (O)thers can't read, can't write and can execute.
- `600`: (chmod a+rwx,u-x,g-rwx,o-rwx) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can't read, can't write and can't execute. (O)thers can't read, can't write and can't execute.
- `644`: (chmod a+rwx,u-x,g-wx,o-wx) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can read, can't write and can't execute. (O)thers can read, can't write and can't execute.
- `666`: (chmod a+rwx,u-x,g-x,o-x) sets permissions so that, (U)ser / owner can read, can write and can't execute. (G)roup can read, can write and can't execute. (O)thers can read, can write and can't execute.
- `755`: (chmod a+rwx,g-w,o-w) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can't write and can execute. (O)thers can read, can't write and can execute.
- `764`: (chmod a+rwx,g-x,o-wx) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can write and can't execute. (O)thers can read, can't write and can't execute.
- `777`: (chmod a+rwx) sets permissions so that, (U)ser / owner can read, can write and can execute. (G)roup can read, can write and can execute. (O)thers can read, can write and can execute.

### Change ownership

- `chgrp`: Change group ownership of files or directories.
- `chgrpr`: Change group ownership of files or directories recursively.
- `chgrpu`: Change group ownership of files or directories recursively to the current user.
- `chmod`: Change file mode bits.
- `chmodr`: Change file mode bits recursively.
- `chmodu`: Change file mode bits recursively to the current user.
- `chmox`: Make a file executable.
- `chown`: Change file owner and group.
- `chownr`: Change file owner and group recursively.
- `chownu`: Change file owner and group recursively to the current user.

### Set permissions for specific file types

- `755d`: Set permissions of all directories to rwxr-xr-x.
- `644f`: Set permissions of all files to rw-r--r--.

### Set permissions for specific user types

- `u+x`: Add execute permission for the owner of the file.
- `u-x`: Remove execute permission for the owner of the file.
- `u+w`: Add write permission for the owner of the file.
- `u-w`: Remove write permission for the owner of the file.
- `u+r`: Add read permission for the owner of the file.
- `u-r`: Remove read permission for the owner of the file.
- `g+x`: Add execute permission for the group owner of the file.
- `g-x`: Remove execute permission for the group owner of the file.
- `g+w`: Add write permission for the group owner of the file.
- `g-w`: Remove write permission for the group owner of the file.
- `g+r`: Add read permission for the group owner of the file.
- `g-r`: Remove read permission for the group owner of the file.
- `o+x`: Add execute permission for others.
- `o-x`: Remove execute permission for others.
- `o+w`: Add write permission for others.
- `o-w`: Remove write permission for others.
- `o+r`: Add read permission for others.
- `o-r`: Remove read permission for others.

### Set permissions based on octal notation

- `000`: Set permissions to ----------
- `400`: Set permissions to r--------
- `444`: Set permissions to r--r--r--
- `600`: Set permissions to rw-------
- `644`: Set permissions to rw-r--r--.
- `664`: Set permissions to rw-rw-r--.
- `755`: Set permissions to rwxr-xr-x.
- `775`: Set permissions to rwxrwxr-x.
- `777`: Set permissions to rwxrwxrwx.
