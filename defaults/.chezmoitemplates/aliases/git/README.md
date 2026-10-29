# Git Aliases

Manage Git aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `git.aliases.sh` and `signing.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

## Aliases

### `git.aliases.sh`

Every definition in this file exists only when `git` is on PATH.

| Name | Definition | Notes |
| --- | --- | --- |
| `git_default_branch` | function |  |
| `git_primary_branch` | function |  |
| `git_current_branch` | function |  |
| `g` | `git` |  |
| `gconfdiff` | `git config alias.dcolor "diff --color-words"` |  |
| `gconfl` | `git config --list` |  |
| `gconfr` | `git config --local --get remote.origin.url` |  |
| `gtp` | `git rev-parse --show-toplevel` |  |
| `grpa` | `git rev-parse --abbrev-ref HEAD` |  |
| `ga` | `git add` |  |
| `gaa` | `git add --all` |  |
| `gad` | `git add .` |  |
| `gau` | `git add --update` |  |
| `gcl` | `git clone` |  |
| `gin` | `git init` |  |
| `gco` | `git checkout` |  |
| `gcb` | `git checkout -b` |  |
| `gdis` | `git checkout --` | Changed from checkout to git checkout for safety checking. |
| `grs` | `git restore` |  |
| `gmv` | `git mv` |  |
| `grm` | `git rm` |  |
| `grmc` | `git rm --cached` |  |
| `gst` | `git status` |  |
| `gsts` | `git status --short` |  |
| `gstsb` | `git status --short --branch` |  |
| `gsta` | `git stash push -m <message>` |  |
| `gstp` | `git stash pop` |  |
| `gstd` | `git stash drop` |  |
| `gclout` | `git clean -df && git checkout -- .` |  |
| `gc` | `git commit -a` |  |
| `gca` | `git commit --amend` |  |
| `gcall` | `git add -A && git commit -av` |  |
| `gcam` | `git commit --amend --message <message>` |  |
| `gcane` | `git commit --amend --no-edit` |  |
| `gcm` | `git commit --message <message>` |  |
| `ci` | `git commit` |  |
| `gd` | `git diff` |  |
| `gdch` | `git diff --name-status` |  |
| `gdh` | `git diff HEAD` |  |
| `gdstaged` | `git diff --staged` |  |
| `gdcached` | `git diff --cached` |  |
| `gdstat` | `git diff --stat --ignore-space-change -r` |  |
| `gl` | `git log --since="last month" --oneline` |  |
| `glg` | `git log --graph --all --oneline --decorate` |  |
| `glgg` | `git log --oneline --graph --full-history --all --color --decorate` |  |
| `lg` | `git log --graph --oneline --decorate --all` |  |
| `glc` | `git log --oneline --reverse` |  |
| `gld` | `git log --since=1-day-ago` |  |
| `gldc` | `git log -1 --date-order --format=%cI` |  |
| `gldl` | `git log --date=local` |  |
| `glf` | `git log ORIG_HEAD.. --stat --no-merges` |  |
| `gll` | `git log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset"` |  |
| `gb` | `git branch` |  |
| `gbd` | `git branch -d` |  |
| `gbl` | `git branch -l` |  |
| `gbr` | `git branch -r` |  |
| `gbrd` | `git branch -d -r` |  |
| `gbrsb` | `git show-branch` |  |
| `gswb` | `git switch` |  |
| `gcode` | function |  |
| `gcom` | function | Only when `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |
| `gf` | `git fetch` |  |
| `gp` | `git pull` |  |
| `gph` | `git push` |  |
| `gpo` | `git push origin` |  |
| `gpb` | function |  |
| `gpoll` | `git push origin --all` |  |
| `lgui` | `lazygit` | Only when `lazygit` is on PATH. |
| `gr` | `git remote` |  |
| `gra` | `git remote add` |  |
| `grall` | `git remote \| xargs -L1 git push --all` |  |
| `grao` | `git remote add origin` |  |
| `grv` | `git remote -v` |  |
| `grev` | `git revert` |  |
| `grevnc` | `git revert --no-commit` |  |
| `grb` | `git rebase` |  |
| `grbk` | `git reset --soft HEAD^` |  |
| `grescl` | function | Only when `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |
| `gresh` | function | Only when `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |
| `gresp` | function | Only when `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |
| `gress` | `git reset --soft HEAD~1` |  |
| `gsm` | `git submodule` |  |
| `gsmi` | `git submodule init` |  |
| `gsma` | `git submodule add` |  |
| `gsms` | `git submodule sync` |  |
| `gsmu` | `git submodule update` |  |
| `gsmui` | `git submodule update --init` |  |
| `gsmuir` | `git submodule update --init --recursive` |  |
| `gg` | `git grep` |  |
| `gbs` | `git bisect` |  |
| `undopush` | function | Only when `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |

### `signing.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `enable-signing` | `enable_signing_fn` | Enable Git Signing (Wizard) |
| `verify-signatures` | `git log --show-signature -n 10` | Verify signatures of latest commits. |
| `check-signing` | `git config --list`, filtered to lines containing `gpg` or `signing` | Check if current config has signing enabled. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
