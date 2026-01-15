#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅶🅸🆃 🅰🅻🅸🅰🆂🅴🆂 - Git aliases.
#
# Sections:
#
#      1.0 Git Core aliases.
#      1.1 Work on the current change.
#      1.2 Start a working area.
#      1.3 Examine the history and state.
#      1.4 List, create, or delete branches.
#      1.5 Collaborate.
#      1.6 Record changes to the repository.
#      1.7 Show changes between commits, commit and working tree, etc.
#      1.8 Show commit logs.
#      1.9  Switch branches or restore working tree files.
#      2.0 Update remote refs along with associated objects.
#      2.1 Aliases to manage set of tracked repositories.
#      2.2 Aliases to revert some existing commits.
#      2.3 Aliases to initialize, update or inspect submodules.
#      2.4 Aliases to show the working tree status.
#      2.5 Aliases to create, list, delete or verify a tag object
#          signed with GPG.
#      2.6 Aliases to show various types of objects.
#      2.7 Aliases to reset current HEAD to the specified state.
#      2.8 Aliases to pick out and massage parameters.
#      2.9 Aliases to remove files from the working tree and from the
#          index.
#      3.0 Aliases to show what revision and author last modified each
#          line of a file.
#      3.1 Aliases to get and set repository or global options.
#
##  --------------------------------------------------------------------
##  1.0 Git Core aliases
##  --------------------------------------------------------------------

##  --------------------------------------------------------------------
##  1.1 Aliases to work on the current change
##  --------------------------------------------------------------------

if command -v git &>/dev/null; then

  # Short-form git commands.
  alias g='git'

  # Add file contents to the index.
  alias ga='git add'

  # Add file contents and update the index not only where the
  # working tree has a file matching <pathspec> but also where the
  # index already has an entry.
  alias gaa='git add --all'

  # Add current directory file contents to the index.
  alias gad='git add .'

  # Add file contents and update the index just where it already has an
  # entry matching <pathspec>.
  alias gau='git add --update'

  # Undo to last commit.
  alias gco='git checkout'

  # Discard changes in a (list of) file(s) in working tree
  alias gdis='checkout --'

  # Move or rename a file, a directory, or a symlink.
  alias gmv='git mv'

  # Restore working tree files.
  alias grs='git restore'

  # Remove files from the working tree and from the index.
  alias grm='git remove'

  # Initialize and modify the sparse-checkout.
  alias gsc='git sparse-checkout'

  ##  ------------------------------------------------------------------
  ##  1.2 Aliases to start a working area
  ##  ------------------------------------------------------------------

  # Clone a repository into a new directory.
  alias gcl='git clone'

  # Create an empty Git repository or reinitialize an existing one.
  alias gin='git init'

  ##  ------------------------------------------------------------------
  ##  1.3 Aliases to examine the history and state
  ##  ------------------------------------------------------------------

  # Use binary search to find the commit that introduced a bug.
  alias gbs='git bisect'

  # Show changes between commits, commit and working tree, etc.
  alias gd='git diff'

  # Print lines matching a pattern.
  alias gg='git grep'

  # Show commit logs this month.
  alias gl='git log --since="last month" --oneline'

  # Show commit logs and Draw a text-based graphical representation of
  # the commit history on the left hand side of the output.
  alias glg='git log --oneline --graph --full-history --all --color --decorate'

  # Show various types of objects.
  alias gs='git show'

  ##  ------------------------------------------------------------------
  ##  1.4 Aliases to list, create, or delete branches
  ##  ------------------------------------------------------------------

  # gb: Create a branch.
  alias gb='git branch'

  # gbd: Delete a branch.
  alias gbd='git branch -d'

  # gbl: List branches.
  alias gbl='git branch -l'

  # gbr: List the remote-tracking branches.
  alias gbr='git branch -r'

  # gbrd: Delete the remote-tracking branches.
  alias gbrd='git branch -d -r'

  # Print a list of branches and their commits.
  alias gbrsb='git show-branch'

  # gct: Record changes to the repository.
  alias gct='git commit'

  # gmg: Join two or more development histories together.
  alias gmg='git merge'

  # grb: Reapply commits on top of another base tip.
  alias grb='git rebase'

  # grs: Reset current HEAD to the specified state.
  alias grs='git reset'

  # gswb: Switch branches.
  alias gswb='git switch'

  ##  ------------------------------------------------------------------
  ##  1.5 Aliases to collaborate
  ##  ------------------------------------------------------------------

  # Create an empty Git repository or reinitialize an existing one.
  alias gi='git init'

  # Download objects and refs from another repository.
  alias gf='git fetch'

  # Fetch from and integrate with another repository or a local branch.
  alias gp='git pull'

  # Update remote refs along with associated objects.
  alias gph='git push'

  ##  ------------------------------------------------------------------
  ##  1.6 Aliases to record changes to the repository
  ##  ------------------------------------------------------------------

  # Commit command to automatically "add" changes from all known files.
  alias gc='git commit -a'

  # Amend the tip of the current branch rather than creating a new
  # commit.
  alias gca='git commit --amend'

  # Commit all changes.
  alias gcall='git add -A && git commit -av'

  # Amend the tip of the current branch, and edit the message.
  alias gcam='git commit --amend --message '

  # Amend the tip of the current branch, and do not edit the message.
  alias gcane='git commit --amend --no-edit'

  # Commit interactive.
  alias gcint='git commit --interactive'

  # Commit with a message.
  alias gcm='git commit --message '

  ##  ------------------------------------------------------------------
  ##  1.7 Aliases to show changes between commits, commit and working
  ##      tree, etc.
  ##  ------------------------------------------------------------------

  # Show changes between the working tree and the index or a tree.
  alias gd='git diff'

  # Show only names and status of changed files.
  alias gdch='git diff --name-status'

  # Show all changes of tracked files which are present in working
  # directory and staging area.
  alias gdh='git diff HEAD'

  # Show changes to files in the "staged" area.
  alias gdstaged='git diff --staged'

  # Shows the changes between the index and the HEAD (which is the last
  # commit on this branch).
  alias gdcached='git diff --cached'

  # Generate a diffstat.
  alias gdstat='git diff --stat --ignore-space-change -r'

  ##  ------------------------------------------------------------------
  ##  1.8 Aliases to show commit logs
  ##  ------------------------------------------------------------------

  # Show log of changes, most recent first.
  alias glc='git log --oneline --reverse'

  # Show the log of the recent day.
  alias gld='git log --since=1-day-ago'

  # Show the date of the latest commit, in strict ISO 8601 format.
  alias gldc='git log -1 --date-order --format=%cI'

  # Show log with dates in our local timezone.
  alias gldl='git log --date=local'

  # Show log of new commits after you fetched, with stats, excluding
  # merges.
  alias glf='git log ORIG_HEAD.. --stat --no-merges'

  # Show the date of the earliest commit, in strict ISO 8601 format.
  alias glfd='!"git log --date-order --format=%cI | tail -1"'

  # Visualization of branch topology.
  alias glfh='git log --graph --full-history --all --color'

  # Show log as a graph.
  alias glg='git log --graph --all --oneline --decorate'

  # Show the log of the recent hour.
  alias glh='git log --since=1-hour-ago'

  # Show log in our preferred format for our key performance indicators.
  alias gll='git log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset"'

  # Show log in our preferred format for our key performance indicators,
  # with long items.
  alias glll='git log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset"'

  # Show the log of the recent month.
  alias glm='git log --since=1-month-ago'

  # Show the log for my own commits by my own user email.
  alias glmy='!git log --author $(git config user.email)'

  # Show the log of the recent week.
  alias glw='git log --since=1-week-ago'

  # Show the log of the recent year.
  alias gly='git log --since=1-year-ago'

  ##  ------------------------------------------------------------------
  ##  1.9  Aliases to switch branches or restore working tree files
  ##  ------------------------------------------------------------------

  # Clean and discard changes and untracked files in working tree.
  alias gclout='git clean -df && git checkout -- .'

  # Switch branches or restore working tree files.
  alias gco='git checkout'

  # Create a new branch named <new_branch> and start it at
  # <start_point>.
  alias gcb='git checkout -b'

  # Delete all local branches that have been merged into the local main
  # branch.
  alias gcode='git checkout main && git branch --merged | xargs git branch --delete'

  # Ensure local is like the main branch.
  alias gcom='git checkout main && git fetch origin --prune && git reset --hard origin/main'

  ##  ------------------------------------------------------------------
  ##  2.0 Aliases to update remote refs along with associated objects
  ##  ------------------------------------------------------------------

  # Publish the current branch by pushing it to the remote "origin", and
  # setting the current branch to track the upstream branch.
  alias gpb='git push --set-upstream origin $(git current-branch)'

  # Push local changes to the online repository.
  alias gpo='git push origin'

  # Push local tags.
  alias gpt='git push --tags'

  # Push each of your local git branches to the remote repository
  alias gpoll='git push origin --all'

  # Fetch from and integrate with another repository or a local branch.
  alias gpull='git pull'

  # Pull changes from the locally stored branch origin/master and merge
  # that to the local checked-out branch.
  alias gpullm='git pull origin master'

  # Do a pull for just one branch.
  alias gpullo='git pull origin $(git current-branch)'

  # Update remote refs along with associated objects.
  alias gpush='git push'

  # Do a push for just one branch.
  alias gpusho='git push origin $(git current-branch)'

  # For each remote branch, push it.
  alias gpushr='git remote | xargs -I% -n1 git push %'

  # Unpublish the current branch by deleting the remote version of the
  # current branch.
  alias gunpub='git push origin :$(git current-branch)'

  # Push current branch
  # alias gpcb='git push origin "$(git branch|grep '\*'|tr -d '* \n')"'

  ##  ------------------------------------------------------------------
  ##  2.1 Aliases to manage set of tracked repositories
  ##  ------------------------------------------------------------------

  # Manage set of tracked repositories.
  alias gr='git remote'

  # Add a remote named <name> for the repository at <url>.
  alias gra='git remote add'

  # Push all branches to all remotes.
  alias grall='git remote | xargs -L1 git push --all'

  # Add a new remote 'origin' if it doesn't exist.
  alias grao='git remote add origin'

  # Rollback to stage.
  alias grbk='git reset --soft HEAD^'

  # Deletes all stale remote-tracking branches under <name>.
  alias grcl='git remote prune'

  # For each remote branch, push it.
  alias grp="git remote | xargs -I% -n1 git push %"

  # Push all remotes.
  # Print the url for the current repo.
  alias grprint="git remote -v | sed -n '/github.com.*push/{ s/^[^[:space:]]\+[[:space:]]\+//; s|git@github.com:|https://github.com/|; s/\.git.*//; p }'"

  # Gives some information about the remote <name>.
  alias grs='git show'

  # Display where the origin resides.
  alias grso='git remote show origin'

  # Fetch updates for a named set of remotes in the repository as
  # defined by remotes.
  alias gru='git remote update'

  # Shows URLs of remote repositories when listing your current remote
  # connections.
  alias grv='git remote -v'

  ##  ------------------------------------------------------------------
  ##  2.2 Aliases to revert some existing commits
  ##  ------------------------------------------------------------------

  # Undo the changes from some existing commits
  alias grev='git revert'

  # Revert without autocommit; useful when you're reverting more than
  # one commits' effect to your index in a row.
  alias grevnc='git revert --no-commit'

  ##  ------------------------------------------------------------------
  ##  2.3 Aliases to initialize, update or inspect submodules
  ##  ------------------------------------------------------------------

  # Enables foreign repositories to be embedded within a dedicated
  # subdirectory of the source tree.
  alias gsm='git submodule'

  # Initialize the submodules recorded in the index
  alias gsmi='git submodule init'

  # Add the given repository as a submodule at the given path to the
  # changeset to be committed next to the current project: the current
  # project is termed the "superproject".
  alias gsma='git submodule add'

  # Synchronizes submodules' remote URL configuration setting to the
  # value specified in .gitmodules.
  alias gsms='git submodule sync'

  # Update the registered submodules to match what the superproject
  # expects by cloning missing submodules, fetching missing commits in
  # submodules and updating the working tree of the submodules.
  alias gsmu='git submodule update'

  # Submodule update with initialize
  alias gsmui='git submodule update --init'

  # Submodule update with initialize and recursive; this is useful to
  # bring a submodule fully up to date.
  alias gsmuir='git submodule update --init --recursive'

  ##  ------------------------------------------------------------------
  ##  2.4 Aliases to show the working tree status
  ##  ------------------------------------------------------------------

  # Show the working tree status.
  alias gst='git status'

  # Stash the changes.
  alias gsta='git stash save '

  # Status with short format instead of full details.
  alias gsts='git status --short'

  # Status with short format and showing branch and tracking info.
  alias gstsb='git status --short --branch'

  ##  ------------------------------------------------------------------
  ##  2.5 Aliases to create, list, delete or verify a tag object
  ##  signed with GPG.
  ##  ------------------------------------------------------------------

  # See all tags.
  alias gt='git tag'

  # Create, list, delete or verify a tag object signed with GPG.
  alias gtg='git tag'

  # Last tag in the current branch.
  alias gtl='git describe --tags --abbrev=0'

  ##  ------------------------------------------------------------------
  ##  2.6 Aliases to show various types of objects.
  ##  ------------------------------------------------------------------

  # Show various types of objects
  alias gshow='git show'

  # Show list of files changed by commit.
  alias gshls='git show --relative --pretty=format:'''

  # Given any git object, try to show it briefly.
  alias gshnp='git show --no-patch --pretty="tformat:%h (%s, %ad)" --date=short'

  # Show who contributed, in descending order by number of commits.
  alias gshwho='git shortlog --summary --numbered --no-merges'

  ##  ------------------------------------------------------------------
  ##  2.7 Aliases to reset current HEAD to the specified state.
  ##  ------------------------------------------------------------------

  # Reset commit clean.
  alias grescl='git reset --hard HEAD~1 && git clean -fd'

  # Reset commit hard.
  alias gresh='git reset --hard HEAD~1'

  # Reset pristine.
  alias gresp='git reset --hard && git clean -ffdx'

  # Reset commit.
  alias gress='git reset --soft HEAD~1'

  # Reset to upstream.
  alias gresu='git reset --hard $(git upstream-branch)'

  ##  ------------------------------------------------------------------
  ##  2.8 Aliases to pick out and massage parameters.
  ##  ------------------------------------------------------------------

  # Get the top level directory name.
  alias gtp='git rev-parse --show-toplevel'

  # Get the current branch name.
  alias grpa='git rev-parse --abbrev-ref HEAD'

  ##  ------------------------------------------------------------------
  ##  2.9 Aliases to remove files from the working tree and from the
  ##      index.
  ##  ------------------------------------------------------------------

  # Remove files from the working tree and from the index.
  alias grm='git rm'

  # Unstage and remove paths only from the index.
  alias grmc='git rm --cached'

  # Remove files which have been deleted.
  alias grmd='git ls-files -z --deleted | xargs -0 git rm'

  # Remove files which have been deleted.
  alias grmd2='git rm $(git ls-files --deleted)'

  # Remove .DS_Store from the repository.
  alias grmds='find . -name .DS_Store -exec git rm --ignore-unmatch --cached {} +'

  # Remove for all deleted files, including those with
  # space/quote/unprintable characters in their filename/path.
  alias grmx='git ls-files -z -d | xargs -0 git rm --'

  ##  ------------------------------------------------------------------
  ##  3.0 Aliases to show what revision and author last modified each
  ##      line of a file.
  ##  ------------------------------------------------------------------

  # Prints per-line contribution per author for a GIT repository.
  # alias gblau='git ls-files | xargs -n1 git blame --line-porcelain | sed -n "s/^author //p" | sort -f | uniq -ic | sort -nr'

  ##  ------------------------------------------------------------------
  ##  3.1 Aliases to get and set repository or global options.
  ##  ------------------------------------------------------------------

  # Better git diff, word delimited and colorized.
  alias gconfdiff='git config alias.dcolor "diff --color-words"'

  # List all the settings.
  alias gconfl='git config --list'

  # Output remote origin from within a local repository.
  alias gconfr='git config --local --get remote.origin.url'

  # Undo the last push.
  alias undopush="git push -f origin HEAD^:master"
fi
