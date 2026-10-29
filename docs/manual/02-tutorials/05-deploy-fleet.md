---
render_with_liquid: false
---

# Tutorial: Deploy to a Fleet

Roll out `.dotfiles` across multiple workstations and check that they're in sync.

## Scenario

You have three hosts:

- **macbook-t2**: your MacBook (current host, already installed)
- **surface-pro**: your Linux laptop (new install)
- **geekom-a9**: your desktop mini PC (new install)

Goal: all three running the same `.dotfiles` with per-host customization, each with a workstation attestation you can collect in one place.

## Step 1: Per-Host Install

On each new host:

```sh
# Download and verify the release installer per the installation guide first.
bash /tmp/dotfiles-install.sh
```

The installer asks no questions. Select the host's preset afterwards in `~/.config/chezmoi/chezmoi.toml`, then run `dot apply`:

- Surface Pro: `machine = "surface-pro"`
- Geekom A9: `machine = "geekom-a9"`

See [Create a Machine Profile](03-create-profile.md) for what a preset controls.

## Step 2: Exchange Signing Keys

Each host has its own SSH ED25519 key. To verify commits across the fleet, every host must trust every other host's public key.

**On each host, copy the public key:**

```sh
cat ~/.ssh/id_ed25519.pub
# ssh-ed25519 AAAAC3N...jkl5 user@macbook-t2
```

Git reads trusted keys from `~/.config/git/allowed_signers`, which chezmoi manages from `defaults/dot_config/git/allowed_signers.tmpl`. **On one host, add all three keys to that source file:**

```sh
dot config edit ~/.config/git/allowed_signers
```

```
user@macbook-t2 ssh-ed25519 AAAAC3N...jkl5
user@surface-pro ssh-ed25519 AAAAC3N...abc7
user@geekom-a9 ssh-ed25519 AAAAC3N...def9
```

Commit and push it:

```sh
cd ~/.dotfiles
git add defaults/dot_config/git/allowed_signers.tmpl
git commit -sS -m "feat(git): add fleet signing keys"
git push
```

Every other host gets the updated list on `dot config update`.

## Step 3: Share the Age Key (for Shared Secrets)

If you want shared secrets decrypted on all three hosts, each host's age public key must be a recipient in `.sops.yaml`.

Option A: Share one key across all hosts (simpler, less granular).
Option B: Each host has its own key; all three are listed as recipients (better operational security).

For Option B, on each host:

```sh
dot secret init                              # creates ~/.config/chezmoi/key.txt if missing
age-keygen -y ~/.config/chezmoi/key.txt      # prints the public key
```

Add all three public keys to `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: .*\.sops\.ya?ml$
    key_groups:
      - age:
          - age1aaa...111   # macbook-t2
          - age1bbb...222   # surface-pro
          - age1ccc...333   # geekom-a9
```

Re-encrypt existing secrets for the new recipients:

```sh
# On macbook-t2
cd ~/.dotfiles
find defaults -name '*.sops.yaml' -exec sops updatekeys --yes {} \;
git add .sops.yaml defaults/
git commit -sS -m "chore(secrets): add fleet recipients"
git push
```

Each host then decrypts with its own private key (see [Encrypt a Secret](04-encrypt-secret.md) for `SOPS_AGE_KEY_FILE`).

## Step 4: Check Fleet Alignment

Each host reports its own state. On any host:

```sh
dot fleet status        # node ID, namespace, version, OS, shell, drift, last apply
dot fleet drift show    # which managed files differ from the source
```

To collect evidence from every host in one place, write each host's attestation to a shared directory (a synced folder or a mounted share):

```sh
dot attest show --fleet-store ~/Sync/attestations --fleet-id home
```

This writes `~/Sync/attestations/home/<hostname>/workstation-attestation.json`, plus a timestamped copy. Each record is unsigned JSON with the dotfiles version, platform, git signing settings, agent mode and MCP posture, so compare `dotfiles_version` and `git_signing` across hosts.

If a host shows drift:

```sh
ssh surface-pro
dot doctor drift show
dot config update
```

## Step 5: Per-Host Customization

Each host has its own `~/.config/chezmoi/chezmoi.toml`: use it for things that shouldn't propagate:

```toml
# surface-pro's chezmoi.toml
[data]
machine = "surface-pro"
theme = "monterey-dark"       # per-host default
default_shell = "fish"
terminal_font_size = 11       # smaller for HiDPI
```

```toml
# geekom-a9's chezmoi.toml
[data]
machine = "geekom-a9"
theme = "sonoma-dark"         # different default
default_shell = "zsh"
terminal_font_size = 14       # larger for external 1440p
```

Both hosts render from the same templates, producing correct platform-appropriate output.

## Step 6: Fleet-Wide Updates

When you push a commit to main, each host pulls independently:

```sh
# On each host
dot config update
```

`dot config update` runs `chezmoi update --force`: it pulls the source in `~/.dotfiles` and applies it, overwriting local edits to managed files without asking (set `DOTFILES_INTERACTIVE_APPLY=1` to be asked). `dot update` is a different command: it updates the whole system (packages and tools), asking first.

To update every host from one machine over SSH, list them in `~/.config/dotfiles/fleet.toml`:

```toml
[hosts.surface-pro]
ssh = "user@surface-pro.local"
profile = "laptop"

[hosts.geekom-a9]
ssh = "user@geekom-a9.local"
profile = "desktop"
```

Then:

```sh
dot fleet apply --dry-run   # print the hosts and the command, connect to none
dot fleet apply             # run 'dot config update && dot doctor' on each host
```

It runs up to four hosts in parallel (`--jobs <n>` changes that); `--host <name>` limits it to one host, and `--verify-hosts` refuses to connect to a host that is not already in `~/.ssh/known_hosts`.

## Step 7: Secrets Rotation

When a secret is compromised (or as part of routine rotation):

```sh
# 1. Edit the secret on any host
cd ~/.dotfiles
sops defaults/.secrets/credentials.sops.yaml
# Change the compromised value, save

# 2. Commit and push
git commit -sS -am "chore(secrets): rotate stripe key"
git push

# 3. All fleet hosts pick up the new value on their next update
dot config update            # on each host, or `dot fleet apply` from one
```

Since every host holds its own age private key, decryption needs no extra step.

## Step 8: Decommission a Host

When retiring a host:

```sh
# 1. Remove the host's public key from allowed_signers
dot config edit ~/.config/git/allowed_signers

# 2. Remove the host's age public key from .sops.yaml

# 3. Re-encrypt all SOPS files without the decommissioned recipient,
#    and replace their data keys
find defaults -name '*.sops.yaml' -exec sops updatekeys --yes {} \;
find defaults -name '*.sops.yaml' -exec sops rotate --in-place {} \;

# 4. Remove its stanza from ~/.config/dotfiles/fleet.toml, then commit
git commit -sS -am "chore(fleet): decommission geekom-a9"
git push
```

Then, on the decommissioned host, run `dot config uninstall`. After a confirmation it deletes `~/.dotfiles`, `~/.config/chezmoi` (including the age key `key.txt`), chezmoi's state and dot's scripts in `~/.local/bin`. Back up anything you still need from those first.

## Troubleshooting

### Fleet Host Unreachable

`dot fleet apply` couldn't SSH to a host. Check:

```sh
ssh surface-pro 'dot --version'
# If this fails, fix SSH connectivity first
```

### Drift on One Host

See what differs:

```sh
ssh surface-pro 'dot doctor drift show'
ssh surface-pro 'chezmoi diff | head -50'
```

Then apply the source again (`dot config update`), or run `dot doctor fix` for the issues `dot doctor` reports.

### Version Mismatch Between Hosts

One host reports an older `dotfiles_version` than the others. Usually that host missed an update:

```sh
ssh surface-pro 'dot config update'
```

### Commit Signature Not Trusted

`git verify-commit` reports no trusted principal: the signing host's key isn't in `~/.config/git/allowed_signers` on the verifying host. Add it (Step 2) and run `dot config update` there.

## Summary

A three-host fleet:

- Installs from one repository
- Has independent signing keys (each host verifies commits from others)
- Can share secrets across specific hosts via SOPS recipients
- Records each host's state with `dot attest show --fleet-store <dir>`
- Updates independently with `dot config update` (or from one host with `dot fleet apply`)

## Next

- [Concept: Fleet Architecture](../01-concepts/04-fleet.md)
- [Reference: Fleet Commands](../03-reference/01-dot-cli.md#dot-fleet)
- [Operations: Fleet Deployment](../../architecture/fleet-deployment.md)
