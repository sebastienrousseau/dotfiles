# Subversion Aliases

Manage Subversion aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `subversion.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `legacy`. Disabled by `aliases.buckets.svn = false` in the chezmoi data. Every definition below exists only when `svn` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `sad` | `svn add` | Put new files and directories under version control. |
| `sau` | `svn auth` | Manage cached authentication credentials. |
| `sbl` | `svn blame` | Show when each line of a file was last (or next) changed. |
| `scg` | `svn changelist` | Associate (or dissociate) changelist CLNAME with the named files. |
| `sci` | `svn commit` | Send changes from your working copy to the repository. |
| `scl` | `svn cleanup` | Either recover from an interrupted operation that left the working copy locked, or remove unwanted files. |
| `sco` | `svn checkout` | Check out a working copy from a repository. |
| `scp` | `svn copy` | Copy files and directories in a working copy or repository. |
| `sct` | `svn cat` | Output the content of specified files or URLs. |
| `sdi` | `svn diff` | Display local changes or differences between two revisions or paths. |
| `sdl` | `svn delete` | Remove files and directories from version control. |
| `shp` | `svn help` | Describe the usage of this program or its subcommands. |
| `sin` | `svn info` | Display information about a local or remote item. |
| `sip` | `svn import` | Commit an unversioned file or tree into the repository. |
| `slg` | `svn log` | Show the log messages for a set of revision(s) and/or path(s). |
| `slk` | `svn lock` | Slock: Lock working copy paths or URLs in the repository, so that no other user can commit changes to them. |
| `sls` | `svn list` | List directory entries in the repository. |
| `smd` | `svn mkdir` | Create a new directory under version control. |
| `smg` | `svn merge` | Merge changes into a working copy. |
| `smgi` | `svn mergeinfo` | Display merge-related information. |
| `smv` | `svn move` | Move (rename) an item in a working copy or repository. |
| `sp` | `svn propset` | Set the value of a property on files, dirs, or revisions. |
| `spdl` | `svn propdel` | Remove a property from files, dirs, or revisions. |
| `spdt` | `svn propedit` | Edit a property with an external editor. |
| `spgt` | `svn propget` | Print the value of a property on files, dirs, or revisions. |
| `sph` | `svn patch` | Apply a patch to a working copy. |
| `spls` | `svn proplist` | List all properties on files, dirs, or revisions. |
| `srl` | `svn relocate` | Relocate the working copy to point to a different repository root URL. |
| `srs` | `svn resolve` | Resolve conflicts on working copy files or directories. |
| `srsd` | `svn resolved` | Remove 'conflicted' state on working copy files or directories. |
| `srv` | `svn revert` | Restore pristine working copy state (undo local changes). |
| `sst` | `svn status` | Print the status of working copy files and directories. |
| `ssw` | `svn switch` | Update the working copy to a different URL within the same repository. |
| `sulk` | `svn unlock` | Unlock working copy paths or URLs. |
| `sup` | `svn update` | Bring changes from the repository into the working copy. |
| `supg` | `svn upgrade` | Upgrade the metadata storage format for a working copy. |
| `sxp` | `svn export` | Create an unversioned copy of a tree. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
