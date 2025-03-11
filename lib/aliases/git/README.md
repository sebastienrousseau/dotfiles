<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🅶🅸🆃 🅰🅻🅸🅰🆂🅴🆂

This is a collection of handy Git aliases that simplify and speed up
common Git commands, making them shorter and more intuitive.

- `gc` Commit command to automatically "add" changes from all known
  files
- `gca` Amend the tip of the current branch rather than creating a new
  commit.
- `gcall` Commit all changes.
- `gcam` Amend the tip of the current branch, and edit the message.
- `gcane` Amend the tip of the current branch, and do not edit the
  message.
- `gcint` Commit interactive.
- `gcm` Commit with a message.
- `gd` Show changes between the working tree and the index or a tree.
- `gdch` Show only names and status of changed files.
- `gdh` Show all changes of tracked files which are present in working
  directory and staging area.
- `gdstaged` Show changes to files in the "staged" area.
- `gdcached` Shows the changes between the index and the HEAD (which is
  the last commit on this branch).
- `gdstat` Generate a diffstat.
- `glc` Show log of changes, most recent first.
- `gld` Show the log of the recent day.
- `gldc` Show the date of the latest commit, in strict ISO 8601 format.
- `gldl` Show log with dates in our local timezone.
- `glf` Show log of new commits after you fetched, with stats, excluding
  merges.
- `glfd` Show the date of the earliest commit, in strict ISO 8601
  format.
- `glfh` Visualization of branch topology.
- `glg` Show log as a graph.
- `glh` Show the log of the recent hour.
- `gll` Show log in our preferred format for our key performance
  indicators.
- `glll` Show log in our preferred format for our key performance
  indicators, with long items.
- `glm` Show the log of the recent month.
- `glmy` Show the log for my own commits by my own user email.
- `glw` Show the log of the recent week.
- `gly` Show the log of the recent year.
- `gclout` Clean and discard changes and untracked files in working
  tree.
- `gco` Switch branches or restore working tree files.
- `gcb` Create a new branch named <new_branch> and start it at
  <start_point>.
- `gcode` Delete all local branches that have been merged into the local
  main branch.
- `gcom` Ensure local is like the main branch.
- `gpb` Publish the current branch by pushing it to the remote "origin",
  and setting the current branch to track the upstream branch.
- `gpo` Push local changes to the online repository.
- `gpt` Push local tags.
- `gpoll` Push each of your local git branches to the remote repository
- `gpull` Fetch from and integrate with another repository or a local
  branch.
- `gpullm` Pull changes from the locally stored branch origin/master
  and merge that to the local checked-out branch.
- `gpullo` Do a pull for just one branch.
- `gpush` Update remote refs along with associated objects.
- `gpusho` Do a push for just one branch.
- `gpushr` For each remote branch, push it.
- `gunpub` Unpublish the current branch by deleting the remote version
  of the current branch.
- `gpcb` Push current branch
- `gr` Manage set of tracked repositories.
- `gra` Add a remote named `name` for the repository at `url`.
- `grall` Push all branches to all remotes.
- `grallo` Git remote all remotes except origin.
- `grao` Add a new remote 'origin' if it doesn't exist.
- `grbk` Rollback to stage.
- `grcl` Deletes all stale remote-tracking branches under `name`.
- `grf` Show GIT Remote Origin for each immediate subfolder.
- `grfall` Fetch all git remotes for a repo.
- `grp` Push all remotes.
- `grprint` Print the url for the current repo.
- `grs` Gives some information about the remote `name`.
- `grso` Display where the origin resides.
- `gru` Fetch updates for a named set of remotes in the repository as
  defined by remotes.
- `grv` Shows URLs of remote repositories when listing your current
  remote connections.
- `grev` Undo the changes from some existing commits
- `grevnc` Revert without autocommit; useful when you're reverting
  more than one commits' effect to your index in a row.
- `gsm` Enables foreign repositories to be embedded within a dedicated
  subdirectory of the source tree.
- `gsmi` Initialize the submodules recorded in the index
- `gsma` Add the given repository as a submodule at the given path to
  the changeset to be committed next to the current project: the current
  project is termed the "superproject".
- `gsms` Synchronizes submodules' remote URL configuration setting to
  the value specified in .gitmodules.
- `gsmu` Update the registered submodules to match what the superproject
  expects by cloning missing submodules, fetching missing commits in
  submodules and updating the working tree of the submodules.
- `gsmui` Submodule update with initialize
- `gsmuir` Submodule update with initialize and recursive; this is
  useful to bring a submodule fully up to date.
- `gst` Show the working tree status.
- `gsta` Stash the changes.
- `gstrmu` Remove untracked files in a git repository.
- `gsts` Status with short format instead of full details.
- `gstsb` Status with short format and showing branch and tracking info.
- `gt` See all tags.
- `gtg` Create, list, delete or verify a tag object signed with GPG.
- `gtl` Last tag in the current branch.
- `gshow` Show various types of objects
- `gshf` Find the nearest parent branch of the current git branch.
- `gshls` Show list of files changed by commit.
- `gshnp` Given any git object, try to show it briefly.
- `gshwho` Show who contributed, in descending order by number of
  commits.
- `grescl` Reset commit clean.
- `gresh` Reset commit hard.
- `gresp` Reset pristine.
- `gress` Reset commit.
- `gresu` Reset to upstream.
- `gtp` Get the top level directory name.
- `grpa` Get the current branch name.
- `gub` Get the upstream branch name.
- `grm` Remove files from the working tree and from the index.
- `grmc` Unstage and remove paths only from the index.
- `grmd` Remove files which have been deleted.
- `grmd2` Remove files which have been deleted.
- `grmds` Remove .DS_Store from the repository.
- `grmx` Remove for all deleted files, including those with space/quote
  unprintable characters in their filename/path.
- `gblau`Prints per-line contribution per author for a GIT repository.
- `gconfdiff` Better git diff, word delimited and colorized.
- `gconfl` List all the settings.
- `gconfr` Output remote origin from within a local repository.
- `undopush` Undo the last push.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
