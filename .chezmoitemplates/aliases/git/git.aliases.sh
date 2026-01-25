# shellcheck shell=bash
# Git Aliases
#
# Sections:
# 1. Core
# 2. Working Area (add, checkout, etc.)
# 3. History (log, diff, show)
# 4. Branches & Remotes
# 5. Advanced (submodules, stashing, etc.)

if command -v git &>/dev/null; then

  # --- Core ---
  alias g='git'
  alias gconfdiff='git config alias.dcolor "diff --color-words"'
  alias gconfl='git config --list'
  alias gconfr='git config --local --get remote.origin.url'
  alias gtp='git rev-parse --show-toplevel'
  alias grpa='git rev-parse --abbrev-ref HEAD'

  # --- Working Area ---
  alias ga='git add'
  alias gaa='git add --all'
  alias gad='git add .'
  alias gau='git add --update'
  
  alias gcl='git clone'
  alias gin='git init'
  
  alias gco='git checkout'
  alias gcb='git checkout -b'
  alias gdis='git checkout --' # changed from checkout to git checkout for safety checking
  alias grs='git restore'
  alias gmv='git mv'
  alias grm='git rm'
  alias grmc='git rm --cached'
  
  alias gst='git status'
  alias gsts='git status --short'
  alias gstsb='git status --short --branch'
  alias st='git status'

  alias gsta='git stash save '
  alias gstp='git stash pop'
  alias gstd='git stash drop'

  alias gclout='git clean -df && git checkout -- .'

  # --- Commits ---
  alias gc='git commit -a'
  alias gca='git commit --amend'
  alias gcall='git add -A && git commit -av'
  alias gcam='git commit --amend --message '
  alias gcane='git commit --amend --no-edit'
  alias gcm='git commit --message '
  alias ci='git commit'
  
  # --- Diff & History ---
  alias gd='git diff'
  alias gdch='git diff --name-status'
  alias gdh='git diff HEAD'
  alias gdstaged='git diff --staged'
  alias gdcached='git diff --cached'
  alias gdstat='git diff --stat --ignore-space-change -r'
  
  alias gl='git log --since="last month" --oneline'
  alias glg='git log --graph --all --oneline --decorate'
  alias glgg='git log --oneline --graph --full-history --all --color --decorate'
  alias lg='git log --graph --oneline --decorate --all'
  alias glc='git log --oneline --reverse'
  alias gld='git log --since=1-day-ago'
  alias gldc='git log -1 --date-order --format=%cI'
  alias gldl='git log --date=local'
  alias glf='git log ORIG_HEAD.. --stat --no-merges'
  alias gll='git log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset"'
  
  # --- Branches ---
  alias gb='git branch'
  alias gbd='git branch -d'
  alias gbl='git branch -l'
  alias gbr='git branch -r'
  alias gbrd='git branch -d -r'
  alias gbrsb='git show-branch'
  alias gswb='git switch'
  alias br='git branch'
  
  alias gcode='git checkout main && git branch --merged | xargs git branch --delete'
  alias gcom='git checkout main && git fetch origin --prune && git reset --hard origin/main'
  alias co='git checkout'

  # --- Remotes & Comparison ---
  alias gf='git fetch'
  alias gp='git pull'
  alias gph='git push'
  alias gpo='git push origin'
  alias gpb='git push --set-upstream origin $(git branch --show-current)'
  alias gpoll='git push origin --all'
  alias gpull='git pull'
  alias gpush='git push'

  # TUI Git
  if command -v lazygit &>/dev/null; then
    alias lgui='lazygit'
  fi
  
  alias gr='git remote'
  alias gra='git remote add'
  alias grall='git remote | xargs -L1 git push --all'
  alias grao='git remote add origin'
  alias grv='git remote -v'

  # --- Revert & Reset ---
  alias grev='git revert'
  alias grevnc='git revert --no-commit'
  alias grb='git rebase'
  alias grbk='git reset --soft HEAD^'
  
  alias grescl='git reset --hard HEAD~1 && git clean -fd'
  alias gresh='git reset --hard HEAD~1'
  alias gresp='git reset --hard && git clean -ffdx'
  alias gress='git reset --soft HEAD~1'

  # --- Submodules ---
  alias gsm='git submodule'
  alias gsmi='git submodule init'
  alias gsma='git submodule add'
  alias gsms='git submodule sync'
  alias gsmu='git submodule update'
  alias gsmui='git submodule update --init'
  alias gsmuir='git submodule update --init --recursive'

  # --- Tools ---
  alias gg='git grep'
  alias gbs='git bisect'
  alias undopush="git push -f origin HEAD^:master"

fi
