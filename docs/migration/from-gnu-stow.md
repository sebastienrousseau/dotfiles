---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Migrating from GNU Stow

Stow builds a symlink farm: `~/.bashrc` is a symlink into
`~/dotfiles/bash/.bashrc`. This framework renders real files into
`$HOME` from a source tree. That difference is the whole migration —
everything else follows from it.

Be honest about whether you want this. If your setup is "symlink a
dozen files on one machine", Stow is doing that job well and the
migration will not repay itself. The reason to move is templating,
multiple machines, or the tooling around the files.

## Concept mapping

| Stow | Here |
|---|---|
| `~/dotfiles/<package>/` | `defaults/` (one tree, not per-package) |
| `stow bash` | `dot sync` (applies everything) |
| `stow -D bash` | `chezmoi forget <file>`, then `dot sync` |
| `stow -n` (simulate) | `dot diff` or `dot sync --check` |
| `.stow-local-ignore` | `.chezmoiignore` |
| Symlinks in `$HOME` | Real files in `$HOME` |
| Per-host: separate packages or branches | `.tmpl` files with `{{ if }}` |

## 1. Record what Stow currently owns

Symlinks are self-describing, which makes this the easiest inventory
of any migration:

```sh
find "$HOME" -maxdepth 3 -type l -lname "*dotfiles*" \
  -printf '%p -> %l\n' 2>/dev/null | tee ~/stow-inventory.txt
```

On macOS (BSD `find` has no `-printf`):

```sh
find "$HOME" -maxdepth 3 -type l | while read -r l; do
  case "$(readlink "$l")" in *dotfiles*) echo "$l -> $(readlink "$l")";; esac
done | tee ~/stow-inventory.txt
```

Back up the real content, following the links:

```sh
tar -czhf ~/stow-backup-$(date +%F).tar.gz -C "$HOME" \
  $(sed 's| ->.*||; s|^'"$HOME"'/||' ~/stow-inventory.txt)
```

`-h` is the important flag: it dereferences symlinks and archives the
actual files.

## 2. Unstow before installing

This is the step people skip, and it is the one that matters. If you
install over a live symlink farm, `chezmoi apply` will try to replace
symlinks with regular files and the result is confusing.

```sh
cd ~/dotfiles
stow -D */          # remove every package's links
find "$HOME" -maxdepth 3 -type l -lname "*dotfiles*" 2>/dev/null   # expect empty
```

Your `~/dotfiles` directory still holds the real files. Nothing is lost.

## 3. Install

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

## 4. Import your files

Stow packages flatten into a single tree. Copy each package's contents
into `$HOME` and add them:

```sh
cd ~/dotfiles
for pkg in */; do
  pkg="${pkg%/}"
  echo "== $pkg"
  ( cd "$pkg" && find . -type f -print0 ) | while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    mkdir -p "$(dirname "$HOME/$rel")"
    cp "$pkg/$rel" "$HOME/$rel"
    dot add "$HOME/$rel"
  done
done
```

Review before committing anything — this is a good moment to drop the
files you have not opened in three years:

```sh
dot status
cd "$(dot cd)" && git status
```

## 5. Replace per-host packages with templates

If you had `bash-work/` and `bash-home/` packages, collapse them:

```text
{{ if eq .chezmoi.hostname "work-laptop" }}
export HTTP_PROXY=http://proxy.corp:3128
{{ end }}
```

Available variables: `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.hostname`,
`.chezmoi.username`, `.chezmoi.osRelease.id`, plus this project's
`.profile` and `.features.*` from `defaults/.chezmoidata.toml`.

Test a template without applying:

```sh
chezmoi execute-template < defaults/dot_bashrc.tmpl
```

## 6. Apply and verify

```sh
dot diff
dot sync
dot doctor

# Nothing should be a symlink into ~/dotfiles any more:
find "$HOME" -maxdepth 3 -type l -lname "*dotfiles*" 2>/dev/null
```

## 7. Retire the old tree

After a few days:

```sh
mv ~/dotfiles ~/dotfiles.stow.bak     # rename, do not delete
# delete ~/dotfiles.stow.bak once you are sure
```

## Rolling back

```sh
bash ~/.dotfiles/scripts/uninstall.sh --force
mv ~/dotfiles.stow.bak ~/dotfiles     # if you renamed it
cd ~/dotfiles && stow */
```

## What you gain, what you lose

**Gain:** templating (the thing Stow structurally cannot do); one tree
instead of a package-per-tool layout; the `dot` CLI; multi-shell
parity; secrets management; signed releases.

**Lose:** the elegance of the symlink model — editing `~/.bashrc` no
longer edits your repo directly, so you edit the source and run
`dot sync` (or `dot add` after the fact). Stow is ~5k lines of Perl
with essentially no runtime dependencies; this pulls in chezmoi. And
Stow's mental model fits in a paragraph, which has real value.
