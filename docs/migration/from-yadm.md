---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Migrating from yadm

yadm is the closest neighbour: both track real files in `$HOME` with
git, both template per host, both encrypt secrets. The migration is
mostly a mechanical re-home of files plus a translation of yadm's
alternate-file suffixes into chezmoi templates.

## Concept mapping

| yadm | Here | Note |
|---|---|---|
| `yadm add` / `yadm commit` | `dot config add` then a normal `git commit` in the source dir | Source tree is a plain git repo |
| `$HOME` **is** the work tree | Files live in `defaults/` and are *rendered* into `$HOME` | The big conceptual change |
| `##os.Linux`, `##hostname.foo` suffixes | `{{ if eq .chezmoi.os "linux" }}` in a `.tmpl` | One file with branches, not N files |
| `yadm alt` | `chezmoi apply` | Automatic; no separate step |
| `yadm encrypt` (GPG) | `dot secret` (age + sops) | Different crypto; see below |
| `yadm bootstrap` | `install/provision/` | Opt-in: runs only with `install.sh --provision` (or `DOTFILES_PROVISION=1`), never on apply |
| `yadm status` / `diff` | `dot status` / `dot diff` | Same intent |

## 1. Inventory and back up

```sh
yadm list -a > ~/yadm-inventory.txt
wc -l ~/yadm-inventory.txt
tar -czf ~/yadm-backup-$(date +%F).tar.gz -C "$HOME" -T ~/yadm-inventory.txt
```

Keep `yadm-inventory.txt`: it is your checklist, and step 5 diffs
against it.

## 2. Install alongside yadm

The installer does not touch yadm's repo (`~/.local/share/yadm/repo.git`)
or its config, so both can coexist while you migrate. It does apply
this repo's defaults over the files in `$HOME`, which is yadm's work
tree, without taking a backup: your step 1 tarball is what you restore
from, and `yadm status` shows what changed.

```sh
# Download and verify the release installer per docs/guides/INSTALL.md first.
bash /tmp/dotfiles-install.sh
dot version
```

If you want to bring your *own* dotfiles repo rather than the
maintainer's defaults, use `dot config init` instead:

```sh
dot config init yourusername --dry-run    # prints the resolved URL and target dir
dot config init yourusername
```

## 3. Move files across

Plain (non-alternate) files first. Put your own versions back over
the defaults the installer wrote, then add them:

```sh
tar -xzf ~/yadm-backup-<date>.tar.gz -C "$HOME"   # your copies, from step 1
while read -r f; do
  case "$f" in
    *##*) continue ;;            # alternates handled in step 4
  esac
  dot config add "$HOME/$f"
done < ~/yadm-inventory.txt
```

`dot config add` wraps `chezmoi add`, so a file in `~/.config/foo/bar` lands
at `defaults/dot_config/foo/bar`. Where the framework already ships that
path as a template (`~/.gitconfig` is `defaults/dot_gitconfig.tmpl`),
chezmoi asks whether to remove the template attribute; answering yes
replaces the framework's template with your plain file. To keep the
template, answer no and merge your settings into it as in step 4.

## 4. Translate alternates into templates

For each `##`-suffixed file, replace the family with one `.tmpl`.

yadm:

```text
~/.gitconfig##os.Darwin
~/.gitconfig##os.Linux
```

Here, one template. The framework already ships
`defaults/dot_gitconfig.tmpl`, with a `[user]` block and per-OS
credential helpers of its own, so merge the branches below into that
file rather than replacing it:

```text
[user]
    name = {{ .name }}
    email = {{ .email }}
{{ if eq .chezmoi.os "darwin" }}
[credential]
    helper = osxkeychain
{{ else if eq .chezmoi.os "linux" }}
[credential]
    helper = cache --timeout=3600
{{ end }}
```

The common yadm conditions map as:

| yadm suffix | chezmoi expression |
|---|---|
| `##os.Darwin` | `eq .chezmoi.os "darwin"` |
| `##os.Linux` | `eq .chezmoi.os "linux"` |
| `##hostname.foo` | `eq .chezmoi.hostname "foo"` |
| `##user.alice` | `eq .chezmoi.username "alice"` |
| `##distro.Ubuntu` | `eq .chezmoi.osRelease.id "ubuntu"` |
| `##default` | the `{{ else }}` branch |

Verify before applying — templates fail loudly, but only when rendered:

```sh
chezmoi execute-template < ~/.dotfiles/defaults/dot_gitconfig.tmpl
dot diff
```

## 5. Migrate encrypted files

yadm uses GPG; this framework uses age via sops. There is no automatic
converter, and that is deliberate — re-encrypting secrets is a step
you should perform consciously.

```sh
# Decrypt with yadm, in a directory that is not the repo.
mkdir -p /tmp/secrets-migration && cd /tmp/secrets-migration
yadm decrypt

# Set up age and re-encrypt.
dot secret init                    # generates the age key
dot secret new                  # creates the encrypted store
dot secret set GITHUB_TOKEN        # one per secret, prompts for the value
dot secret list

cd - && rm -rf /tmp/secrets-migration
```

Details and the provider model: [`../security/SECRETS.md`](../security/SECRETS.md).

## 6. Apply and verify

```sh
dot diff          # review every pending change
dot sync          # apply
dot doctor        # health check
```

Then diff against the inventory to catch anything missed:

```sh
while read -r f; do
  [ -e "$HOME/$f" ] || echo "MISSING: $f"
done < ~/yadm-inventory.txt
```

## 7. Retire yadm

Only after a full working day on the new setup:

```sh
yadm list -a > ~/yadm-final-check.txt   # last snapshot, keep it
rm -rf ~/.local/share/yadm
rm -rf ~/.config/yadm
# and remove the yadm package via your package manager
```

## Rolling back

At any point before step 7, yadm is untouched:

```sh
bash ~/.dotfiles/scripts/uninstall.sh --force
tar -xzf ~/yadm-backup-<date>.tar.gz -C "$HOME"
yadm status
```

## What you gain, what you lose

**Gain:** one templated file instead of alternate families; the `dot`
CLI (`dot doctor`, `dot doctor status`, `dot doctor fix`,
`dot doctor rollback`, `dot attest`); multi-shell
parity including fish, nushell and PowerShell; signed and attested
releases; fleet commands for more than one machine.

**Lose:** `$HOME` is no longer a git work tree, so `git status` in your
home directory stops being meaningful — you use `dot status` instead.
GPG-encrypted files become age/sops. yadm is a single ~2k-line script;
this is a larger surface. And yadm's bootstrap is one file, whereas
provisioning here is spread across `install/provision/` and runs only
when you ask for it with `install.sh --provision`.
