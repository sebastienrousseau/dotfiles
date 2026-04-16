# Tutorial: Deploy to a Fleet

Roll out `.dotfiles` across multiple workstations and verify they're in sync.

## Scenario

You have three hosts:

- **macbook-t2** — your MacBook (current host, already installed)
- **surface-pro** — your Linux laptop (new install)
- **geekom-a9** — your desktop NUC (new install)

Goal: all three running identical `.dotfiles` with per-host customization, with auditable cross-host attestation.

## Step 1: Per-Host Install

On each new host:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
```

During `chezmoi init`, answer with the host's preset:

- Surface Pro → `machine = "surface-pro"`
- Geekom A9 → `machine = "geekom-a9"`

## Step 2: Exchange Signing Keys

Each host has its own SSH ED25519 key. To verify commits and attestations across the fleet, publish each host's public key to every other host.

**On each host, copy the public key:**

```sh
cat ~/.ssh/id_ed25519.pub
# ssh-ed25519 AAAAC3N...jkl5 user@macbook-t2
```

**Collect all three keys. Append them to `~/.ssh/allowed_signers` on every host:**

```
user@macbook-t2 ssh-ed25519 AAAAC3N...jkl5
user@surface-pro ssh-ed25519 AAAAC3N...abc7
user@geekom-a9 ssh-ed25519 AAAAC3N...def9
```

Optionally commit `allowed_signers` as a template so all hosts receive updates via `dot update`:

```sh
# On macbook-t2
chezmoi add ~/.ssh/allowed_signers
git add -A && git commit -sS -m "feat(ssh): add fleet signing keys"
git push
```

Now every other host gets the updated list on `dot update`.

## Step 3: Share the Age Key (for Shared Secrets)

If you want shared secrets decrypted on all three hosts, each host must have an Age key recipient in `.sops.yaml`.

Option A: Share one key across all hosts (simpler, less granular).
Option B: Each host has its own key; all three are listed as recipients (better operational security).

For Option B:

```sh
# On macbook-t2 (already set up)
grep "public key:" ~/.config/age/keys.txt

# On surface-pro
age-keygen -o ~/.config/age/keys.txt
grep "public key:" ~/.config/age/keys.txt

# On geekom-a9
age-keygen -o ~/.config/age/keys.txt
grep "public key:" ~/.config/age/keys.txt
```

Add all three public keys to `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: \.sops\.yaml$
    age: >-
      age1aaa...111,    # macbook-t2
      age1bbb...222,    # surface-pro
      age1ccc...333     # geekom-a9
```

Re-encrypt existing secrets for the new recipients:

```sh
# On macbook-t2
find . -name '*.sops.yaml' -exec sops updatekeys {} \;
git add .sops.yaml dot_config/*.sops.yaml
git commit -sS -m "chore(secrets): add fleet recipients"
git push
```

Other hosts on `dot update` decrypt with their own private key automatically.

## Step 4: Verify Fleet Alignment

From any host:

```sh
dot fleet attest
```

Expected output:

```
Fleet Attestation — v0.2.500

Host           Git SHA    Policy    Tools OK   Drift   Verified
-------------- ---------- --------- ---------- ------- --------
macbook-t2     abc123d    0x7f2a…   ✓          0       ✓
surface-pro    abc123d    0x7f2a…   ✓          0       ✓
geekom-a9      abc123d    0x7f2a…   ✓          0       ✓
-------------- ---------- --------- ---------- ------- --------
FLEET STATUS: 3/3 aligned
```

If any row shows drift or missing verification:

```sh
# Check which host is out of sync
dot fleet diff

# SSH into the affected host and fix
ssh surface-pro
dot doctor && dot heal
dot update
```

## Step 5: Per-Host Customization

Each host has its own `~/.config/chezmoi/chezmoi.toml` — use it for things that shouldn't propagate:

```toml
# surface-pro's chezmoi.toml
[data]
machine = "surface-pro"
theme = "dome-dark"           # per-host default
default_shell = "fish"
terminal_font_size = 11       # smaller for HiDPI
```

```toml
# geekom-a9's chezmoi.toml
[data]
machine = "geekom-a9"
theme = "valley-dark"         # different default
default_shell = "zsh"
terminal_font_size = 14       # larger for external 1440p
```

Both hosts render from the same templates, producing correct platform-appropriate output.

## Step 6: Fleet-Wide Updates

When you push a commit to master, each host pulls independently:

```sh
# On each host
dot update
```

`dot update` does:

1. `git pull --rebase --autostash` in `~/.dotfiles`
2. `chezmoi apply` with progress output
3. `dot heal` if apply detected drift
4. Reports changes applied

For simultaneous update across the fleet (requires SSH):

```sh
dot fleet sync
# Connects to each host in parallel
# Runs `dot update` via SSH
# Collects outcomes
```

## Step 7: Secrets Rotation

When a secret is compromised (or as part of routine rotation):

```sh
# 1. Edit the secret on any host
sops dot_config/credentials.sops.yaml
# Change the compromised value, save

# 2. Commit and push
git commit -sS -am "chore(secrets): rotate stripe key"
git push

# 3. All fleet hosts pick up the new value on next update
# On each host:
dot update
```

Since hosts all have the Age private key for themselves, decryption is automatic.

## Step 8: Decommission a Host

When retiring a host:

```sh
# 1. Remove the host's public key from allowed_signers
# Edit dot_ssh/allowed_signers.tmpl (on any host)

# 2. Remove the host's Age public key from .sops.yaml

# 3. Re-encrypt all SOPS files (remove the decommissioned recipient)
find . -name '*.sops.yaml' -exec sops updatekeys {} \;

# 4. Commit
git commit -sS -am "chore(fleet): decommission geekom-a9"
git push

# 5. On the decommissioned host: wipe the dotfiles state
rm -rf ~/.dotfiles ~/.local/bin/dot ~/.config/chezmoi ~/.config/age
```

## Troubleshooting

### "Fleet host unreachable"

`dot fleet` couldn't SSH to a host. Check:

```sh
ssh surface-pro 'dot version'
# If this fails, fix SSH connectivity first
```

### Drift on One Host

Run `dot heal` on that host:

```sh
ssh surface-pro 'dot heal'
```

If drift persists:

```sh
ssh surface-pro 'chezmoi diff | head -50'
# Inspect what's different
```

### Policy Hash Mismatch

One host has an older policy than the others. Usually means that host missed an update:

```sh
ssh surface-pro 'dot update'
```

### Attestation Signature Failed

The host's SSH key isn't in `~/.ssh/allowed_signers` on the verifying host. Fix by redistributing `allowed_signers`.

## Summary

A three-host fleet:

- Installs from one repository
- Has independent signing keys (each host verifies commits from others)
- Can share secrets across specific hosts via SOPS recipients
- Is auditable via `dot fleet attest`
- Updates independently with `dot update` (or in parallel with `dot fleet sync`)

## Next

- [Concept: Fleet Architecture](../01-concepts/04-fleet.md)
- [Reference: Fleet Commands](../03-reference/01-dot-cli.md#fleet)
- [Operations: Fleet Deployment](../../architecture/fleet-deployment.md)
