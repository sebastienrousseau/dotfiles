---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Migrating from plain chezmoi

The shortest migration here, because there is no engine change: this
framework *is* chezmoi, plus a source-tree layout, a CLI, and the
tooling around them. Your templates, your `.chezmoidata`, and your
muscle memory all carry over.

You can also stop after step 2 and keep using `chezmoi` commands
directly forever. Nothing here replaces chezmoi; `dot` shells out to it.

## What actually changes

| Plain chezmoi | Here |
|---|---|
| Source at `~/.local/share/chezmoi` | Source at `~/.dotfiles`, with `.chezmoiroot` pointing chezmoi at `defaults/` |
| Everything at the source root | `defaults/` = your files; `bin/`, `lib/`, `scripts/`, `docs/`, `tests/` = the framework |
| `chezmoi apply` | `dot sync` (which runs `chezmoi apply` with sensible exclusions) |
| `chezmoi diff` / `status` | `dot diff` / `dot status` — same thing, prettier |
| — | `dot doctor`, `dot health`, `dot heal`, `dot rollback`, `dot attest` |
| `chezmoi secret` | `dot secrets` (age + sops) |
| `run_onchange_` scripts | same, plus `install/provision/` |

**`.chezmoiroot` is the key idea.** It contains `defaults`, so chezmoi
treats `~/.dotfiles/defaults/` as the source root. Framework code sits
outside that directory and is therefore never deployed to `$HOME`.

## 1. Back up and record

```sh
chezmoi source-path
chezmoi managed > ~/chezmoi-managed.txt
wc -l ~/chezmoi-managed.txt

cp -a "$(chezmoi source-path)" ~/chezmoi-source-backup-$(date +%F)
tar -czf ~/chezmoi-backup-$(date +%F).tar.gz -C "$HOME" -T ~/chezmoi-managed.txt
```

Commit and push your existing source repo if it has a remote. That is
the real backup.

## 2. Two paths

**A. Keep your own repo** (you have a dotfiles repo you want to keep
as the source of truth): install the framework, then move your files
into `defaults/`.

**B. Adopt this repo's defaults** and layer your changes on top:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

Path A continues below.

## 3. Install and relocate your source tree

```sh
old_source="$(chezmoi source-path)"

bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"

# Copy your source files under defaults/, preserving chezmoi's naming.
rsync -av --exclude '.git' "$old_source/" ~/.dotfiles/defaults/
```

Then reconcile the chezmoi-metadata files, which now exist in both
places — merge yours into the framework's rather than overwriting:

| File | What to do |
|---|---|
| `.chezmoidata.toml` | **Merge.** The framework's carries `dotfiles_version`, `profile`, and `features`; keep those and add your keys. |
| `.chezmoiignore` | Merge; the framework's entries are feature-flag-gated. |
| `.chezmoi.toml.tmpl` | Merge your prompts into the framework's. |
| `.chezmoitemplates/` | Merge; name collisions are the only risk. |
| `.chezmoiscripts/`, `run_*` | Copy across as-is. |

Sanity-check the merge before applying anything:

```sh
cd ~/.dotfiles
chezmoi --source "$PWD" data | head -40
chezmoi --source "$PWD" managed | head
```

## 4. Preview, then apply

```sh
dot diff              # or: chezmoi diff — identical underneath
dot sync --check      # dry run
dot sync
dot doctor
```

Confirm nothing was dropped:

```sh
while read -r f; do
  [ -e "$f" ] || echo "MISSING: $f"
done < ~/chezmoi-managed.txt
```

## 5. Optional: adopt the extras

None of these are required; adopt them when you want them.

```sh
dot secrets-init      # age-based secrets
dot theme list        # wallpaper-driven theming
dot profile show      # profiles and feature flags
dot completion fish > ~/.config/fish/completions/dot.fish
```

## Rolling back

The gentlest rollback of any of these guides, because chezmoi is still
the engine:

```sh
chezmoi --source ~/chezmoi-source-backup-<date> apply
bash ~/.dotfiles/scripts/uninstall.sh --force
```

Or simply point chezmoi back at your old source and carry on:

```sh
chezmoi init --source ~/chezmoi-source-backup-<date>
```

## What you gain, what you lose

**Gain:** the `dot` CLI (diagnostics, repair, rollback, attestation,
fleet); a curated multi-shell configuration with parity across bash,
zsh, fish, nushell and PowerShell; secrets, theming and provisioning
already wired; a test suite and CI you can run against your own
changes; signed, attested releases.

**Lose:** simplicity. Plain chezmoi is one binary and your files;
this adds a source-tree convention, a CLI layer, and opinions about
shell configuration you may not share. If you already have a chezmoi
setup you are happy with, "it works and I understand every line" is a
perfectly good reason to stay.
