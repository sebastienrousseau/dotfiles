#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.455) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# 🆂🆄🅱🆅🅴🆁🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂 - Subversion aliases.

  ##  ----------------------------------------------------------------------------
  ##  1.0 Subversion Core aliases.
  ##  ----------------------------------------------------------------------------

  # sad: Put new files and directories under version control.
  alias sad='svn add'

  # sau: Manage cached authentication credentials.
  alias sau='svn auth'

  # sbl: Show when each line of a file was last (or next) changed.
  alias sbl='svn blame'

  # scg: Associate (or dissociate) changelist CLNAME with the named files.
  alias scg='svn changelist'

  # sco: Check out a working copy from a repository.
  alias sco='svn checkout'

  # scl: Either recover from an interrupted operation that left the working copy
  #      locked, or remove unwanted files.
  alias scl='svn cleanup'

  # sci: Send changes from your working copy to the repository.
  alias sci='svn commit'

  # scp: Copy files and directories in a working copy or repository.
  alias scp='svn copy'

  # sct: Output the content of specified files or URLs.
  alias sct='svn cat'

  # sdi: Display local changes or differences between two revisions or paths.
  alias sdi='svn diff'

  # sdl: Remove files and directories from version control.
  alias sdl='svn delete'

  # shp: Describe the usage of this program or its subcommands.
  alias shp='svn help'

  # sin: Display information about a local or remote item.
  alias sin='svn info'

  # sip: Commit an unversioned file or tree into the repository.
  alias sip='svn import'

  # slg: Show the log messages for a set of revision(s) and/or path(s).
  alias slg='svn log'

  # slock: Lock working copy paths or URLs in the repository, so that no other
  #        user can commit changes to them.
  alias slk='svn lock'

  # sls: List directory entries in the repository.
  alias sls='svn list'

  # smd: Create a new directory under version control.
  alias smd='svn mkdir'

  # smg: Merge changes into a working copy.
  alias smg='svn merge'

  # smgi: Display merge-related information.
  alias smgi='svn mergeinfo'

  # smv: Move (rename) an item in a working copy or repository.
  alias smv='svn move'

  # sp: Set the value of a property on files, dirs, or revisions.
  alias sp='svn propset'

  # spdl: Remove a property from files, dirs, or revisions.
  alias spdl='svn propdel'

  # spdt: Edit a property with an external editor.
  alias spdt='svn propedit'

  # spgt: Print the value of a property on files, dirs, or revisions.
  alias spgt='svn propget'

  # sph: Apply a patch to a working copy.
  alias sph='svn patch'

  # spls: List all properties on files, dirs, or revisions.
  alias spls='svn proplist'

  # srl: Relocate the working copy to point to a different repository root URL.
  alias srl='svn relocate'

  # srs: Resolve conflicts on working copy files or directories.
  alias srs='svn resolve'

  # srsd: Remove 'conflicted' state on working copy files or directories.
  alias srsd='svn resolved'

  # srv: Restore pristine working copy state (undo local changes).
  alias srv='svn revert'

  # sst: Print the status of working copy files and directories.
  alias sst='svn status'

  # ssw: Update the working copy to a different URL within the same repository.
  alias ssw='svn switch'

  # sulk: Unlock working copy paths or URLs.
  alias sulk='svn unlock'

  # sup: Bring changes from the repository into the working copy.
  alias sup='svn update'

  # supg: Upgrade the metadata storage format for a working copy.
  alias supg='svn upgrade'

  # sxp: Create an unversioned copy of a tree.
  alias sxp='svn export'
