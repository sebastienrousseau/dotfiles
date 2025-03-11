#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🆂🆄🅱🆅🅴🆁🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂
if command -v 'svn' >/dev/null; then
  alias sad='svn add'        # sad: Put new files and directories under version control.
  alias sau='svn auth'       # sau: Manage cached authentication credentials.
  alias sbl='svn blame'      # sbl: Show when each line of a file was last (or next) changed.
  alias scg='svn changelist' # scg: Associate (or dissociate) changelist CLNAME with the named files.
  alias sci='svn commit'     # sci: Send changes from your working copy to the repository.
  alias scl='svn cleanup'    # scl: Either recover from an interrupted operation that left the working copy locked, or remove unwanted files.
  alias sco='svn checkout'   # sco: Check out a working copy from a repository.
  alias scp='svn copy'       # scp: Copy files and directories in a working copy or repository.
  alias sct='svn cat'        # sct: Output the content of specified files or URLs.
  alias sdi='svn diff'       # sdi: Display local changes or differences between two revisions or paths.
  alias sdl='svn delete'     # sdl: Remove files and directories from version control.
  alias shp='svn help'       # shp: Describe the usage of this program or its subcommands.
  alias sin='svn info'       # sin: Display information about a local or remote item.
  alias sip='svn import'     # sip: Commit an unversioned file or tree into the repository.
  alias slg='svn log'        # slg: Show the log messages for a set of revision(s) and/or path(s).
  alias slk='svn lock'       # slock: Lock working copy paths or URLs in the repository, so that no other user can commit changes to them.
  alias sls='svn list'       # sls: List directory entries in the repository.
  alias smd='svn mkdir'      # smd: Create a new directory under version control.
  alias smg='svn merge'      # smg: Merge changes into a working copy.
  alias smgi='svn mergeinfo' # smgi: Display merge-related information.
  alias smv='svn move'       # smv: Move (rename) an item in a working copy or repository.
  alias sp='svn propset'     # sp: Set the value of a property on files, dirs, or revisions.
  alias spdl='svn propdel'   # spdl: Remove a property from files, dirs, or revisions.
  alias spdt='svn propedit'  # spdt: Edit a property with an external editor.
  alias spgt='svn propget'   # spgt: Print the value of a property on files, dirs, or revisions.
  alias sph='svn patch'      # sph: Apply a patch to a working copy.
  alias spls='svn proplist'  # spls: List all properties on files, dirs, or revisions.
  alias srl='svn relocate'   # srl: Relocate the working copy to point to a different repository root URL.
  alias srs='svn resolve'    # srs: Resolve conflicts on working copy files or directories.
  alias srsd='svn resolved'  # srsd: Remove 'conflicted' state on working copy files or directories.
  alias srv='svn revert'     # srv: Restore pristine working copy state (undo local changes).
  alias sst='svn status'     # sst: Print the status of working copy files and directories.
  alias ssw='svn switch'     # ssw: Update the working copy to a different URL within the same repository.
  alias sulk='svn unlock'    # sulk: Unlock working copy paths or URLs.
  alias sup='svn update'     # sup: Bring changes from the repository into the working copy.
  alias supg='svn upgrade'   # supg: Upgrade the metadata storage format for a working copy.
  alias sxp='svn export'     # sxp: Create an unversioned copy of a tree.
fi
