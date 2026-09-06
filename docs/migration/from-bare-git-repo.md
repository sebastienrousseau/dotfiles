---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Migrating from a bare git repo

The `git --git-dir=$HOME/.dotfiles --work-tree=$HOME` pattern, usually
behind a `config` alias. No dependencies, no symlinks, no templating —
and `$HOME` is the work tree, which is the part that has to change.

## Concept mapping

| Bare repo | Here |
|---|---|
| `config add ~/.bashrc` | `dot add ~/.bashrc` |
| `config commit` / `config push` | ordinary `git` inside `$(dot cd)` |
| `config status` | `dot status` |
| `config checkout` on a new machine | `dot init <user>` |
| `.gitignore` with `*` at `$HOME` | not needed — `$HOME` is not a work tree |
| `showUntrackedFiles = no` | not needed, same reason |
| Per-host: branches | `.tmpl` files with `{{ if }}` |
| Nothing | `dot doctor`, `dot heal`, `dot rollback`, secrets, provisioning |

## 1. Inventory and back up

```sh
alias config='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

config ls-files > ~/bare-inventory.txt
wc -l ~/bare-inventory.txt
tar -czf ~/bare-backup-$(date +%F).tar.gz -C "$HOME" -T ~/bare-inventory.txt
```

Push first if the repo has a remote — the safest rollback is a clone:

```sh
config status
config push
```

## 2. Note your branch layout

Per-host branches are the one thing that needs a design decision. List
them before you start:

```sh
config branch -a
config log --oneline --graph --all | head -20
```

Every branch becomes conditional blocks in one file. Diff two branches
now, while the context is fresh:

```sh
config diff main work-laptop -- .bashrc
```

## 3. Install

The bare repo is at `$HOME/.dotfiles`, which is also this project's
default clone location. The installer detects and refuses to clobber
it, but move it first to avoid the confusion entirely:

```sh
mv "$HOME/.dotfiles" "$HOME/.dotfiles.bare.bak"
alias config='git --git-dir=$HOME/.dotfiles.bare.bak --work-tree=$HOME'

bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

Your files in `$HOME` are untouched by the move — only the git
metadata directory changed name.

## 4. Import

```sh
while read -r f; do
  [ -e "$HOME/$f" ] && dot add "$HOME/$f"
done < ~/bare-inventory.txt

dot status
```

## 5. Collapse branches into templates

Take the differences you diffed in step 2 and express them as
conditions in a single `.tmpl`:

```text
export EDITOR=nvim
{{ if eq .chezmoi.hostname "work-laptop" }}
export HTTP_PROXY=http://proxy.corp:3128
export NPM_CONFIG_REGISTRY=https://nexus.corp/repository/npm/
{{ end }}
{{ if eq .chezmoi.os "darwin" }}
export HOMEBREW_NO_ANALYTICS=1
{{ end }}
```

Rendering is testable without applying:

```sh
chezmoi execute-template < defaults/dot_bashrc.tmpl
```

## 6. Apply and verify

```sh
dot diff
dot sync
dot doctor

while read -r f; do
  [ -e "$HOME/$f" ] || echo "MISSING: $f"
done < ~/bare-inventory.txt
```

## 7. Clean up

```sh
# Only if you had the $HOME/.gitignore containing '*' trick:
grep -q '^\*$' "$HOME/.gitignore" 2>/dev/null && $EDITOR "$HOME/.gitignore"

# Remove the alias from your shell rc, then, once confident:
rm -rf "$HOME/.dotfiles.bare.bak"
```

Do not remove the backup until you have pushed the new source tree
somewhere and used it for a while.

## Rolling back

```sh
bash ~/.dotfiles/scripts/uninstall.sh --force
mv "$HOME/.dotfiles.bare.bak" "$HOME/.dotfiles"
git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout -- .
```

Or, if you pushed in step 1, clone the remote bare again — which is
why step 1 says to push.

## What you gain, what you lose

**Gain:** templating instead of branch-per-host (the bare-repo
pattern's real weakness: merging a change across five host branches);
a CLI with diagnostics and repair; secrets; provisioning hooks;
multi-shell parity; signed releases.

**Lose:** zero dependencies. The bare-repo trick needs nothing but
git, and that is a genuine virtue — especially on a locked-down host.
You also lose `$HOME` as a work tree, so `git status` there no longer
tells you what changed; `dot status` does. And the setup no longer
fits in a three-line shell alias you can retype from memory.
