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
| `yadm add` / `yadm commit` | `dot add` then a normal `git commit` in the source dir | Source tree is a plain git repo |
| `$HOME` **is** the work tree | Files live in `defaults/` and are *rendered* into `$HOME` | The big conceptual change |
| `##os.Linux`, `##hostname.foo` suffixes | `{{ if eq .chezmoi.os "linux" }}` in a `.tmpl` | One file with branches, not N files |
| `yadm alt` | `chezmoi apply` | Automatic; no separate step |
| `yadm encrypt` (GPG) | `dot secrets` (age + sops) | Different crypto; see below |
| `yadm bootstrap` | `install/provision/run_onchange_*` | Runs on apply, idempotent |
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
or its config, so both can coexist while you migrate.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
dot version
```

If you want to bring your *own* dotfiles repo rather than the
maintainer's defaults, use `dot init` instead:

```sh
dot init yourusername --dry-run    # prints the resolved URL and target dir
dot init yourusername
```

## 3. Move files across

Plain (non-alternate) files first:

```sh
while read -r f; do
  case "$f" in
    *##*) continue ;;            # alternates handled in step 4
  esac
  dot add "$f"
done < ~/yadm-inventory.txt
```

`dot add` wraps `chezmoi add`, so a file in `~/.config/foo/bar` lands
at `defaults/dot_config/foo/bar`, and `~/.gitconfig` at
`defaults/dot_gitconfig`.

## 4. Translate alternates into templates

For each `##`-suffixed file, replace the family with one `.tmpl`.

yadm:

```text
~/.gitconfig##os.Darwin
~/.gitconfig##os.Linux
```

Here — `defaults/dot_gitconfig.tmpl`:

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
chezmoi execute-template < defaults/dot_gitconfig.tmpl
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
dot secrets-init                    # generates the age key
dot secrets-create                  # creates the encrypted store
dot secrets set GITHUB_TOKEN        # one per secret, prompts for the value
dot secrets list

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
CLI (`doctor`, `health`, `heal`, `rollback`, `attest`); multi-shell
parity including fish, nushell and PowerShell; signed and attested
releases; fleet commands for more than one machine.

**Lose:** `$HOME` is no longer a git work tree, so `git status` in your
home directory stops being meaningful — you use `dot status` instead.
GPG-encrypted files become age/sops. yadm is a single ~2k-line script;
this is a larger surface. And yadm's bootstrap is one file, whereas
provisioning here is spread across `install/provision/`.
