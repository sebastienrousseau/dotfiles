# Dotfiles aliases

The `suversion.aliases.zsh` file creates helpful shortcut aliases for many
commonly [Suversion](https://subversion.apache.org) commands.

## Table of Contents

- [Dotfiles aliases](#dotfiles-aliases)
  - [Table of Contents](#table-of-contents)
    - [1.0 Subversion Core aliases](#10-subversion-core-aliases)

### 1.0 Subversion Core aliases

| Alias | Command                                  | Description                                        |
| ----- | ---------------------------------------- | -------------------------------------------------- |
| sad    | `svn add`         |  sad: Put new files and directories under version control.  |
| sau    | `svn auth`        |  sau: Manage cached authentication credentials.  |
| sbl    | `svn blame`       |  sbl: Show when each line of a file was last (or next) changed.  |
| scg    | `svn changelist`  |  scg: Associate (or dissociate) changelist CLNAME with the named files.  |
| sco    | `svn checkout`    |  sco: Check out a working copy from a repository.  |
| scl    | `svn cleanup`     |  scl: Either recover from an interrupted operation that left the working copy locked, or remove unwanted file  |
| sci    | `svn commit`      |  sci: Send changes from your working copy to the repository.  |
| scp    | `svn copy`        |  scp: Copy files and directories in a working copy or repository.  |
| sct    | `svn cat`         |  sct: Output the content of specified files or URLs.  |
| sdi    | `svn diff`        |  sdi: Display local changes or differences between two revisions or paths.  |
| sdl    | `svn delete`      |  sdl: Remove files and directories from version control.  |
| shp    | `svn help`        |  shp: Describe the usage of this program or its subcommands.  |
| sin    | `svn info`        |  sin: Display information about a local or remote item.  |
| sip    | `svn import`      |  sip: Commit an unversioned file or tree into the repository.  |
| slg    | `svn log`         |  slg: Show the log messages for a set of revision(s) and/or path(s).  |
| slk    | `svn lock`        |  slock: Lock working copy paths or URLs in the repository, no other user can commit changes to them.  |
| sls    | `svn list`        |  sls: List directory entries in the repository.  |
| smd    | `svn mkdir`       |  smd: Create a new directory under version control.  |
| smg    | `svn merge`       |  smg: Merge changes into a working copy.  |
| smgi   | `svn mergeinfo`   |  smgi: Display merge-related information.  |
| smv    | `svn move`        |  smv: Move (rename) an item in a working copy or repository.  |
| sp     | `svn propset`     |  sp: Set the value of a property on files, dirs, or revisions.  |
| spdl   | `svn propdel`     |  spdl: Remove a property from files, dirs, or revisions.  |
| spdt   | `svn propedit`    |  spdt: Edit a property with an external editor.  |
| spgt   | `svn propget`     |  spgt: Print the value of a property on files, dirs, or revisions.  |
| sph    | `svn patch`       |  sph: Apply a patch to a working copy.  |
| spls   | `svn proplist`    |  spls: List all properties on files, dirs, or revisions.  |
| srl    | `svn relocate`    |  srl: Relocate the working copy to point to a different repository root URL.  |
| srs    | `svn resolve`     |  srs: Resolve conflicts on working copy files or directories.  |
| srsd   | `svn resolved`    |  srsd: Remove 'conflicted' state on working copy files or directories.  |
| srv    | `svn revert`      |  srv: Restore pristine working copy state (undo local changes).  |
| sst    | `svn status`      |  sst: Print the status of working copy files and directories.  |
| ssw    | `svn switch`      |  ssw: Update the working copy to a different URL within the same repository.  |
| sulk   | `svn unlock`      |  sulk: Unlock working copy paths or URLs.  |
| sup    | `svn update`      |  sup: Bring changes from the repository into the working copy.  |
| supg   | `svn upgrade`     |  supg: Upgrade the metadata storage format for a working copy.  |
| sxp    | `svn export`      |  sxp: Create an unversioned copy of a tree.  |
