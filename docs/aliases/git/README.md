# Git Core Aliases

The `git.aliases.zsh` file creates helpful shortcut aliases for many commonly
[Git](https://www.heroku.com/) commands.

## Aliases to work on the current change

| Alias | Command | Description |
| ----- | ----- | ----- |
| g | `git` | Short-form git commands. |
| ga | `git add` | Add file contents to the index. |
| gaa | `git add --all` | Add file contents and update the index not only where the working tree has a file matching <pathspec> but also where the index already has an entry. |
| gad | `git add .` | Add current directory file contents to the index. |
| gau | `git add --update` | Add file contents and update the index just where it already has an entry matching <pathspec>. |
| gco | `git checkout` | Undo to last commit. |
| gdis | `git checkout --` | Discard changes in a (list of) file(s) in working tree. |
| gmv | `git mv` | Move or rename a file, a directory, or a symlink. |
| grs | `git restore` | Restore working tree files. |
| gsc | `git sparse-checkout` | Initialize and modify the sparse-checkout. |

## Aliases to start a working area

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcl | `git clone` | Clone a repository into a new directory. |
| gin | `git init` | Create an empty Git repository or reinitialize an existing one. |

## Aliases to examine the history and state

| Alias | Command | Description |
| ----- | ----- | ----- |
| gbs | `git bisect` | Use binary search to find the commit that introduced a bug. |
| gd | `git diff` | Show changes between commits, commit and working tree, etc.|
| gg | `git grep` | Print lines matching a pattern. |
| gl | `git log --since="last month" --oneline` | Show commit logs this month. |
| glg | `git log --oneline --graph --full-history --all --color --decorate` | Show commit logs and Draw a text-based graphical representation of the commit history on the left hand side of the output. |
| gs | `git show` | Show various types of objects. |

## Aliases to list, create, or delete branches

| Alias | Command | Description |
| ----- | ----- | ----- |
| gb | `git branch` | Create a branch. |
| gbd | `git branch -d` | Delete a branch. |
| gbl | `git branch -l` | List branches. |
| gbr | `git branch -r` | List the remote-tracking branches. |
| gbrd | `git branch -d -r` | Delete the remote-tracking branches. |
| gbrsb | `git show-branch` | Print a list of branches and their commits. |
| gct | `git commit` | Record changes to the repository. |
| gmg | `git merge` | Join two or more development histories together. |
| grb | `git rebase` | Reapply commits on top of another base tip. |
| grs | `git reset` | Reset current HEAD to the specified state. |
| gswb | `git switch` | Switch branches. |

## Aliases to collaborate

| Alias | Command | Description |
| ----- | ----- | ----- |
| gf | `git fetch` | Download objects and refs from another repository. |
| gi | `git init` | Create an empty Git repository or reinitialize an existing one. |
| gp | `git pull` | Fetch from and integrate with another repository or a local branch. |
| gpu | `git push` | Update remote refs along with associated objects. |

## Aliases to record changes to the repository

| Alias | Command | Description |
| ----- | ----- | ----- |
| gc | `git commit -a` | Commit command to automatically "add" changes from all known files. |
| gca | `git commit --amend` | Amend the tip of the current branch rather than creating a new commit. |
| gcall | `git add -A && git commit -av` | Commit all changes. |
| gcam | `git commit --amend --message` | Amend the tip of the current branch, and edit the message. |
| gcane | `git commit --amend --no-edit` | Amend the tip of the current branch, and do not edit the message. |
| gcint | `git commit --interactive` | Commit interactive. |
| gcm | `git commit --message` | Commit with a message. |

## Aliases to show changes between commits, commit and working tree, etc

| Alias | Command | Description |
| ----- | ----- | ----- |
| gd | `git diff` | Show changes between the working tree and the index or a tree. |
| gdcached | `git diff --cached` | Shows the changes between the index and the HEAD (which is the last commit on this branch). |
| gdch | `git diff --name-status` | Show only names and status of changed files. |
| gdh | `git diff HEAD` | Show all changes of tracked files which are present in working directory and staging area. |
| gdstaged | `git diff --staged` | Show changes to files in the "staged" area. |
| gdstat | `git diff --stat --ignore-space-change -r` | Generate a diffstat. |

## Aliases to show commit logs

| Alias | Command | Description |
| ----- | ----- | ----- |
| gclc | `git log --oneline --reverse` | Show log of changes, most recent first. |
| gld | `git log --since=1-day-ago` | Show the log of the recent day |
| gldc | `git log -1 --date-order --format=%cI` | Show the date of the latest commit, in strict ISO 8601 format.|
| gldl | `git log --date=local` | Show log with dates in our local timezone. |
| glf | `git log ORIG_HEAD.. --stat --no-merges` | Show log of new commits after you fetched, with stats, excluding merges. |
| glfd | `!"git log --date-order --format=%cI | tail -1"` | Show the date of the earliest commit, in strict ISO 8601 format. |
| glfh | `git log --graph --full-history --all --color` | Visualization of branch topology. |
| glg | `git log --graph --all --oneline --decorate` | Show log as a graph. |
| glh | `git log --since=1-hour-ago` | Show the log of the recent hour |
| gll | `git log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset"` | Show log in our preferred format for our key performance indicators. A.k.a. `ll`. |
| glll | `git log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset"` | Show log in our preferred format for our key performance indicators, with long items. A.k.a. `lll`. |
| glm | `git log --since=1-month-ago` | Show the log of the recent month |
| glmy | `!git log --author $(git config user.email)` | Show the log for my own commits by my own user email. |
| glw | `git log --since=1-week-ago` | Show the log of the recent week |
| gly | `git log --since=1-year-ago` | Show the log of the recent year |

## Aliases to switch branches or restore working tree files

| Alias | Command | Description |
| ----- | ----- | ----- |
| gclout | `git clean -df && git checkout -- .` | Clean and discard changes and un-tracked files in working tree. |
| gco | `git checkout` | Switch branches or restore working tree files. |
| gcob | `git checkout -b` | Create a new branch named <new_branch> and start it at <start_point>. |
| gcode | `git checkout main && git branch --merged | xargs git branch --delete` | Delete all local branches that have been merged into the local main branch. |
| gcom | `git checkout main && git fetch origin --prune && git reset --hard origin/main` | Ensure local is like the main branch. |

## Aliases to update remote refs along with associated objects

| Alias | Command | Description |
| ----- | ----- | ----- |
| gpb | `git push --set-upstream origin $(git current-branch)` | Publish the current branch by pushing it to the remote "origin", and setting the current branch to track the upstream branch. |
| gpcb | `git push origin "$(git branch|grep '\*'|tr -d '* \n')"` | Push current branch |
| gpo | `git push origin` | Push local changes to the online repository. |
| gpoll | `git push origin --all` | Push each of your local git branches to the remote repository |
| gpt | `git push --tags` | Push local tags. |
| gpull | `git pull` | Fetch from and integrate with another repository or a local branch. |
| gpullo | `git pull origin $(git current-branch)` | Do a pull for just one branch. |
| gpullm | `git pull origin master` | Pull changes from the locally stored branch origin/master and merge that to the local checked-out branch. |
| gpush | `git push` | Update remote refs along with associated objects. |
| gpusho | `git push origin $(git current-branch)` | Do a push for just one branch. |
| gpushr | `git remote | xargs -I% -n1 git push %` | git remotes-push - For each remote branch, push it. |
| gunpub | `git push origin :$(git current-branch)` | Un-publish the current branch by deleting the remote version of the current branch. |

## Aliases to manage set of tracked repositories

| Alias | Command | Description |
| ----- | ----- | ----- |
| gr | `git remote` | Manage set of tracked repositories. |
| gra | `git remote add` | Add a remote named <name> for the repository at <url>. |
| grall | `git remote | xargs -L1 git push --all` | Push all branches to all remotes. |
| grallo | `git remote -v | grep "(fetch)" | | Git remote all remotes except origin. |
| grao | `git remote add origin` | Add a new remote 'origin' if it doesn't exist. |
| grbk | `git reset --soft HEAD^` | Rollback to stage. |
| grcl | `git remote prune` | Deletes all stale remote-tracking branches under <name>. |
| grf | `find . -maxdepth 1 -type d \( ! -name . \) -exec bash -c "cd '{}' && echo '{}' && git config --get remote.origin.url" \;` | Show GIT Remote Origin for each immediate subfolder. |
| grfall | `git branch -r | awk -F'/' '{print "git fetch "$1,$2}' | xargs -I {} sh -c {}` | Fetch all git remotes for a repo. |
| gro | `open`git remote -v | awk '/fetch/{print $2}' | sed -Ee 's#(git@|git://)#http://#' -e 's@com:@com/@'`| head -n1` | Open current Git repository URL. |
| grp | `git remote | xargs -I% -n1 git push %` | For each remote branch, push it. |
| grpa | `for i in`git remote`; do git push $i; done;` | Push all remotes. |
| grprint | `git remote -v` | | Print the url for the current repo. |
| grs | `git show` | Gives some information about the remote <name>. |
| grso | `git remote show origin` | Display where the origin resides. |
| grv | `git remote -v` | Shows URLs of remote repositories when listing your current remote connections. |
| gru | `git remote update` | Fetch updates for a named set of remotes in the repository as defined by remotes. |

## Aliases to revert some existing commits

| Alias | Command | Description |
| ----- | ----- | ----- |
| grev | `git revert` | Undo the changes from some existing commits. |
| grevnc | `git revert --no-commit` | Revert without autocommit; useful when you're reverting more than one commits' effect to your index in a row. |

## Aliases to initialize, update or inspect submodules

| Alias | Command | Description |
| ----- | ----- | ----- |
| gsmi | `git submodule init` | Initialize the submodules recorded in the index. |
| gsma | `git submodule add` | Add the given repository as a Submodule at the given path to the changeset to be committed next to the current project: the current project is termed the "superproject". |
| gsm | `git submodule` | Enables foreign repositories to be embedded within a dedicated subdirectory of the source tree. |
| gsms | `git submodule sync` | Synchronizes submodules' remote URL configuration setting to the value specified in .gitmodules. |
| gsmu | `git submodule update` | Update the registered submodules to match what the superproject expects by cloning missing submodules, fetching missing commits in submodules and updating the working tree of the submodules. |
| gsmui | `git submodule update --init` | Submodule update with initialize. |
| gsmuir | `git submodule update --init --recursive` | Submodule update with initialize and recursive; this is useful to bring a submodule fully up to datec. |

## Aliases to show the working tree status

| Alias | Command | Description |
| ----- | ----- | ----- |
| gst | `git status` | Show the working tree status. |
| gstrmu | `git status -su | cut -d' ' -f2- | tr '\n' '\0' | xargs -0 rm` | Remove untracked files in a git repository. |
| gsts | `git status --short` | Status with short format instead of full details. |
| gstsb | `git status --short --branch` | Status with short format and showing branch and tracking info. |

## Aliases to create, list, delete or verify a tag object signed with GPG

| Alias | Command | Description |
| ----- | ----- | ----- |
| gt | `git tag` | gt: See all tags. |
| gta | `git tag -a $1 -m $2` | gta: Add a tag. |
| gtg | `git tag` | gtg: Create, list, delete or verify a tag object signed with GPG. |
| gtl | `git describe --tags --abbrev=0` | gtl: Last tag in the current branch. |
| gtrm | `for t in`git tag`do; git push origin :$t; git tag -d $t; done` | gtrm: Delete all tags. |

## Aliases to show various types of objects

| Alias | Command | Description |
| ----- | ----- | ----- |
| gshab | `for k in ``git branch|perl -pe s/^..//``;do echo  ``git show --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k|head -n 1``\\t$k;done|sort -r` | Show git branches by date - useful for showing active branches. |
| gshf | | Find the nearest parent branch of the current git branch. |
| gshls | `git show --relative --pretty=format:''` | Show list of files changed by commit. |
| gshnp | `git show --no-patch --pretty="tformat:%h (%s, %ad)" --date=short` | Given any git object, try to show it briefly. |
| gshwho | `git shortlog --summary --numbered --no-merges` | Show who contributed, in descending order by number of commits. |

## Aliases to reset current HEAD to the specified state

| Alias | Command | Description |
| ----- | ----- | ----- |
| grescl | `git reset --hard HEAD~1 && git clean -fd` | Reset commit clean. |
| gresh | `git reset --hard HEAD~1` | Reset commit hard. |
| gresp | `git reset --hard && git clean -ffdx` | Reset pristine. |
| gress | `git reset --soft HEAD~1` | Reset commit. |
| gresu | `git reset --hard $(git upstream-branch)` | Reset to upstream. |

## Aliases to pick out and massage parameters

| Alias | Command | Description |
| ----- | ----- | ----- |
| gtp | `git rev-parse --show-toplevel` | Get the top level directory name. |
| gcb | `git rev-parse --abbrev-ref HEAD` | Get the current branch name. |
| gub | `git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD)` | Get the upstream branch name. |

## Aliases to remove files from the working tree and from the index

| Alias | Command | Description |
| ----- | ----- | ----- |
| grm | `git rm` | Remove files from the working tree and from the index.
| grmc | `git rm --cached` | Unstage and remove paths only from the index.
| grmd | `git ls-files -z --deleted | xargs -0 git rm` | git remove files which have been deleted. |
| grmd2 | `git rm $(git ls-files --deleted)` | git remove files which have been deleted. |
| grmds | `find . -name .DS_Store -exec git rm --ignore-unmatch --cached {} +` | Remove .DS_Store from the repository. |
| grmn | `for file in $(git status | grep "new file" | sed "s/#\tnew file://"); do git rm --cached $file; done` | Remove all new files. |
| grmx | `git ls-files -z -d | xargs -0 git rm --` | Remove for all deleted files, including those with space/quote/unprintable characters in their filename/path. |

## Aliases to show what revision and author last modified each line of a file

| Alias | Command | Description |
| ----- | ----- | ----- |
| gbl | `git blame --date short "$1"` | Specifies a format used to output short dates. |
| gblc | `git blame --line-porcelain "$1" | sed -n 's/^author //p' | sort | uniq -c | sort -rn` | Count the number of lines attributed to each author. |
| gblau | `git ls-files | xargs -n1 git blame --line-porcelain | sed -n 's/^author //p' | sort -f | uniq -ic | sort -nr` | Prints per-line contribution per author for a GIT repository. |

## Aliases to get and set repository or global options

| Alias | Command | Description |
| ----- | ----- | ----- |
| gconfdiff | `git config alias.dcolor "diff --color-words"` | Better git diff, word delimited and colorized. |
| gconfl | `git config --list` | List all the settings. |
| gconfr | `git config --local --get remote.origin.url` | Output remote origin from within a local repository. |
