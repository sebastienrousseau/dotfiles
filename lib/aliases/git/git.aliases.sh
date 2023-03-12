#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.464) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅶🅸🆃 🅰🅻🅸🅰🆂🅴🆂 - Git aliases.

if command -v 'git' >/dev/null; then
  alias g='git'                                                                 # g: Short-form git commands.
  alias ga='git add'                                                            # ga: Add file contents to the index.
  alias gaa='git add --all'                                                     # gaa: Add file contents and update the index not only where the working tree has a file matching <pathspec> but also where the index already has an entry.
  alias gad='git add .'                                                         # gad: Add current directory file contents to the index.
  alias gau='git add --update'                                                  # gau: Add file contents and update the index just where it already has an entry matching <pathspec>.
  alias gco='git checkout'                                                      # gco: Undo to last commit.
  alias gdis='checkout --'                                                      # gdis: Discard changes in a (list of) file(s) in working tree
  alias gmv='git mv'                                                            # gmv: Move or rename a file, a directory, or a symlink.
  alias grs='git restore'                                                       # grs: Restore working tree files.
  alias grm='git remove'                                                        # grm: Remove files from the working tree and from the index.
  alias gsc='git sparse-checkout'                                               # gsc: Initialize and modify the sparse-checkout.
  alias gcl='git clone'                                                         # gcl: Clone a repository into a new directory.
  alias gin='git init'                                                          # gin: Create an empty Git repository or reinitialize an existing one.
  alias gbs='git bisect'                                                        # gbs: Use binary search to find the commit that introduced a bug.
  alias gd='git diff'                                                           # gd: Show changes between commits, commit and working tree, etc.
  alias gg='git grep'                                                           # gg: Print lines matching a pattern.
  alias gl='git log --since="last month" --oneline'                             # gl: Show commit logs this month.
  alias glg='git log --oneline --graph --full-history --all --color --decorate' # glg: Show commit logs and Draw a text-based graphical representation of the commit history on the left hand side of the output.
  alias gs='git show'                                                           # Show various types of objects.
  alias gb='git branch'                                                         # gb: Create a branch.
  alias gbd='git branch -d'                                                     # gbd: Delete a branch.
  alias gbl='git branch -l'                                                     # gbl: List branches.
  alias gbr='git branch -r'                                                     # gbr: List the remote-tracking branches.
  alias gbrd='git branch -d -r'                                                 # gbrd: Delete the remote-tracking branches.
  alias gbrsb='git show-branch'                                                 # Print a list of branches and their commits.
  alias gct='git commit'                                                        # gct: Record changes to the repository.
  alias gmg='git merge'                                                         # gmg: Join two or more development histories together.
  alias grb='git rebase'                                                        # grb: Reapply commits on top of another base tip.
  alias grs='git reset'                                                         # grs: Reset current HEAD to the specified state.
  alias gswb='git switch'                                                       # gswb: Switch branches.
  alias gi='git init'                                                           # gi: Create an empty Git repository or reinitialize an existing one.
  alias gf='git fetch'                                                          # gf: Download objects and refs from another repository.
  alias gp='git pull'                                                           # gp: Fetch from and integrate with another repository or a local branch.
  alias gph='git push'                                                          # Update remote refs along with associated objects.
  alias gc='git commit -a'                                                      # Commit command to automatically "add" changes from all known files.
  alias gca='git commit --amend'                                                # Amend the tip of the current branch rather than creating a new commit.
  alias gcall='git add -A && git commit -av'                                    # Commit all changes.
  alias gcam='git commit --amend --message'                                     # Amend the tip of the current branch, and edit the message.
  alias gcane='git commit --amend --no-edit'                                    # Amend the tip of the current branch, and do not edit the message.
  alias gcint='git commit --interactive'                                        # Commit interactive.
  alias gcm='git commit --message '                                             # Commit with a message.
  alias gd='git diff'                                                           # Show changes between the working tree and the index or a tree.
  alias gdch='git diff --name-status'                                           # Show only names and status of changed files.
  alias gdh='git diff HEAD'                                                     # Show all changes of tracked files which are present in working directory and staging area.
  alias gdstaged='git diff --staged'                                            # Show changes to files in the "staged" area.
  alias gdcached='git diff --cached'                                            # Shows the changes between the index and the HEAD (which is the last commit on this branch).
  alias gdstat='git diff --stat --ignore-space-change -r'                       # Generate a diffstat.
  alias glc='git log --oneline --reverse'                                       # Show log of changes, most recent first.
  alias gld='git log --since=1-day-ago'                                         # Show the log of the recent day.
  alias gldc='git log -1 --date-order --format=%cI'                             # Show the date of the latest commit, in strict ISO 8601 format.
  alias gldl='git log --date=local'                                             # Show log with dates in our local timezone.
  alias glf='git log ORIG_HEAD.. --stat --no-merges'                            # Show log of new commits after you fetched, with stats, excluding merges.
  alias glfd='!"git log --date-order --format=%cI | tail -1"'                   # Show the date of the earliest commit, in strict ISO 8601 format.
  alias glfh='git log --graph --full-history --all --color'                     # Visualization of branch topology.
  alias glg='git log --graph --all --oneline --decorate'                        # Show log as a graph.
  alias glh='git log --since=1-hour-ago'                                        # Show the log of the recent hour.
  # Show log in our preferred format for our key performance indicators. A.k.a. `ll`.
  alias gll='git log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset"'
  # Show log in our preferred format for our key performance indicators, with long items. A.k.a. `lll`.
  alias glll='git log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset"'
  alias glm='git log --since=1-month-ago'                                                    # Show the log of the recent month.
  alias glmy='!git log --author $(git config user.email)'                                    # Show the log for my own commits by my own user email.
  alias glw='git log --since=1-week-ago'                                                     # Show the log of the recent week.
  alias gly='git log --since=1-year-ago'                                                     # Show the log of the recent year.
  alias gclout='git clean -df && git checkout -- .'                                          # Clean and discard changes and untracked files in working tree.
  alias gco='git checkout'                                                                   # Switch branches or restore working tree files.
  alias gcb='git checkout -b'                                                                # Create a new branch named <new_branch> and start it at <start_point>.
  alias gcode='git checkout main && git branch --merged | xargs git branch --delete'         # Delete all local branches that have been merged into the local main branch.
  alias gcom='git checkout main && git fetch origin --prune && git reset --hard origin/main' # Ensure local is like the main branch.
  alias gpb='git push --set-upstream origin $(git current-branch)'                           # Publish the current branch by pushing it to the remote "origin", and setting the current branch to track the upstream branch.
  alias gpo='git push origin'                                                                # Push local changes to the online repository.
  alias gpt='git push --tags'                                                                # Push local tags.
  alias gpoll='git push origin --all'                                                        # Push each of your local git branches to the remote repository
  alias gpull='git pull'                                                                     # Fetch from and integrate with another repository or a local branch.
  alias gpullm='git pull origin master'                                                      # Pull changes from the locally stored branch origin/master and merge that to the local checked-out branch.
  alias gpullo='git pull origin $(git current-branch)'                                       # Do a pull for just one branch.
  alias gpush='git push'                                                                     # Update remote refs along with associated objects.
  alias gpusho='git push origin $(git current-branch)'                                       # Do a push for just one branch.
  alias gpushr='git remote | xargs -I% -n1 git push %'                                       # For each remote branch, push it.
  alias gunpub='git push origin :$(git current-branch)'                                      # Unpublish the current branch by deleting the remote version of the current branch.
  alias gr='git remote'                                                                      # Manage set of tracked repositories.
  alias gra='git remote add'                                                                 # Add a remote named name for the repository at url.
  alias grall='git remote | xargs -L1 git push --all'                                        # Push all branches to all remotes.
  alias grao='git remote add origin'                                                         # Add a new remote 'origin' if it doesn't exist.
  alias grbk='git reset --soft HEAD^'                                                        # Rollback to stage.
  alias grcl='git remote prune'                                                              # Deletes all stale remote-tracking branches under <name>.
  alias grp="git remote | xargs -I% -n1 git push %"                                          # For each remote branch, push it.
  # Push all remotes. Print the url for the current repo.
  alias grprint="git remote -v | sed -n '/github.com.*push/{s/^[^[:space:]]\+[[:space:]]\+//;s|git@github.com:|https://github.com/|;s/\.git.*//;p}"
  alias grs='git show'                                                             # Gives some information about the remote <name>.
  alias grso='git remote show origin'                                              # Display where the origin resides.
  alias gru='git remote update'                                                    # Fetch updates for a named set of remotes in the repository as defined by remotes.
  alias grv='git remote -v'                                                        # Shows URLs of remote repositories when listing your current remote connections.
  alias grev='git revert'                                                          # Undo the changes from some existing commits
  alias grevnc='git revert --no-commit'                                            # Revert without autocommit; useful when you're reverting more than one commits' effect to your index in a row.
  alias gsm='git submodule'                                                        # Enables foreign repositories to be embedded within a dedicated subdirectory of the source tree.
  alias gsmi='git submodule init'                                                  # Initialize the submodules recorded in the index
  alias gsma='git submodule add'                                                   # Add the given repository as a submodule at the given path to the changeset to be committed next to the current project: the current project is termed the "superproject".
  alias gsms='git submodule sync'                                                  # Synchronizes submodules' remote URL configuration setting to the value specified in .gitmodules.
  alias gsmu='git submodule update'                                                # Update the registered submodules to match what the superproject expects by cloning missing submodules, fetching missing commits in submodules and updating the working tree of the submodules.
  alias gsmui='git submodule update --init'                                        # Submodule update with initialize
  alias gsmuir='git submodule update --init --recursive'                           # Submodule update with initialize and recursive; this is useful to bring a submodule fully up to date.
  alias gst='git status'                                                           # Show the working tree status.
  alias gsta='git stash save '                                                     # Stash the changes.
  alias gsts='git status --short'                                                  # Status with short format instead of full details.
  alias gstsb='git status --short --branch'                                        # Status with short format and showing branch and tracking info.
  alias gt='git tag'                                                               # See all tags.
  alias gtg='git tag'                                                              # Create, list, delete or verify a tag object signed with GPG.
  alias gtl='git describe --tags --abbrev=0'                                       # Last tag in the current branch.
  alias gshow='git show'                                                           # Show various types of objects
  alias gshls='git show --relative --pretty=format:'''                             # Show list of files changed by commit.
  alias gshnp='git show --no-patch --pretty="tformat:%h (%s, %ad)" --date=short'   # Given any git object, try to show it briefly.
  alias gshwho='git shortlog --summary --numbered --no-merges'                     # Show who contributed, in descending order by number of commits.
  alias grescl='git reset --hard HEAD~1 && git clean -fd'                          # Reset commit clean.
  alias gresh='git reset --hard HEAD~1'                                            # Reset commit hard.
  alias gresp='git reset --hard && git clean -ffdx'                                # Reset pristine.
  alias gress='git reset --soft HEAD~1'                                            # Reset commit.
  alias gresu='git reset --hard $(git upstream-branch)'                            # Reset to upstream.
  alias gtp='git rev-parse --show-toplevel'                                        # Get the top level directory name.
  alias grpa='git rev-parse --abbrev-ref HEAD'                                     # Get the current branch name.
  alias grm='git rm'                                                               # Remove files from the working tree and from the index.
  alias grmc='git rm --cached'                                                     # Unstage and remove paths only from the index.
  alias grmd='git ls-files -z --deleted | xargs -0 git rm'                         # Remove files which have been deleted.
  alias grmd2='git rm $(git ls-files --deleted)'                                   # Remove files which have been deleted.
  alias grmds='find . -name .DS_Store -exec git rm --ignore-unmatch --cached {} +' # Remove .DS_Store from the repository.
  alias grmx='git ls-files -z -d | xargs -0 git rm --'                             # Remove for all deleted files, including those with space/quote/unprintable characters in their filename/path.
  alias gconfdiff='git config alias.dcolor "diff --color-words"'                   # Better git diff, word delimited and colorized.
  alias gconfl='git config --list'                                                 # List all the settings.
  alias gconfr='git config --local --get remote.origin.url'                        # Output remote origin from within a local repository.
  alias undopush="git push -f origin HEAD^:master"                                 # undopush: Undo the last push.
fi
