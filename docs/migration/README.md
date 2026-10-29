---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Migration guides

Coming from another dotfiles manager. One guide per tool, each with
real commands, a rollback path, and an honest section on what you lose
by switching.

| You use | Guide | Rough effort |
|---|---|---|
| [yadm](https://yadm.io/) | [`from-yadm.md`](from-yadm.md) | 30 min — closest model, both wrap git and template |
| [GNU Stow](https://www.gnu.org/software/stow/) | [`from-gnu-stow.md`](from-gnu-stow.md) | 1–2 h — symlink farm to managed copies is a real change |
| A bare git repo (`--git-dir=$HOME/.dotfiles`) | [`from-bare-git-repo.md`](from-bare-git-repo.md) | 45 min |
| Plain chezmoi, no framework | [`from-plain-chezmoi.md`](from-plain-chezmoi.md) | 10 min — same engine underneath |

Upgrading between versions of *this* project is a different document:
[`../operations/MIGRATION.md`](../operations/MIGRATION.md).

## Read this first

Three facts that apply to every guide.

**chezmoi is the engine.** This project is a framework *over*
[chezmoi](https://www.chezmoi.io/), not a replacement for it. Files
live in a source tree, `chezmoi apply` renders them into `$HOME`, and
`dot` is a control plane over that. If you already know chezmoi, you
already know 80% of this.

**The installer applies this repo's defaults.** `install.sh` clones
the framework to `~/.dotfiles` and runs `chezmoi apply`, which
overwrites every file the defaults manage (`~/.bashrc`, `~/.zshrc`,
`~/.gitconfig`, much of `~/.config`) without asking. It copies the
originals to `~/.dotfiles.bak.<timestamp>` only when it finds a
chezmoi setup to compare against (an existing `~/.dotfiles` or
`~/.local/share/chezmoi` git checkout, or an existing chezmoi config);
a first install from the release installer takes no backup. So every guide below starts with
your own backup. After the install, `dot diff` and `dot sync --check`
preview changes without writing.

**You can leave.** `dot config uninstall --force` removes the repo, the
chezmoi config (keeping your age key), state and cache, and the dotfiles
caches and logs.
Your files stay where they were applied; nothing phones home and
nothing is left behind to reinstall itself. Each guide ends with the
rollback for that specific migration.

## The shape of every migration

```sh
# 1. Back up. Always.
tar -czf ~/dotfiles-backup-$(date +%F).tar.gz -C "$HOME" \
  .bashrc .zshrc .config .gitconfig 2>/dev/null || true

# 2. After the verified release download in docs/guides/INSTALL.md,
#    install the framework. This overwrites the files the defaults manage.
bash /tmp/dotfiles-install.sh

# 3. Restore your own files from the backup, then bring them under
#    management one at a time (each replaces the default for that path).
tar -xzf ~/dotfiles-backup-<date>.tar.gz -C "$HOME" .config/nvim
dot config add ~/.config/nvim

# 4. Preview, then apply.
dot diff
dot sync

# 5. Check the result.
dot doctor
```

Step 3 is where the guides differ, because it depends on how your
current tool stores things.

## Choosing not to switch

Genuinely reasonable reasons to stay where you are:

- **You only symlink a handful of files and never templated anything.**
  GNU Stow is simpler and does that job well.
- **You need Windows-native support without WSL or PowerShell 7.**
- **You do not want a CLI layer.** Plain chezmoi is a smaller surface.

The case for switching is multi-machine fleets, per-host templating,
multi-shell parity, and signed/attested releases. If none of those
describe you, the migration cost may not repay itself.
