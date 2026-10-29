---
render_with_liquid: false
---

# Key Rotation Guide

This page tracks two distinct key lifecycles:

1. **Disclosure key**: the GPG key reporters use to encrypt vulnerability reports to the maintainer. Single key, public, valid for three years and rotated before expiry or on compromise. Source of truth for the active fingerprint is `SECURITY.md`.
2. **Secrets encryption keys**: the Age and SOPS keys that protect the encrypted files in your chezmoi source. Multiple keys, per-machine, rotated annually or on personnel / device change.

Both sections live here so a single audit can confirm the project's
posture across encrypted-disclosure-in and encrypted-secrets-at-rest.

## Disclosure Key (GPG)

Closes the rotation half of [#870](https://github.com/sebastienrousseau/dotfiles/issues/870).

### Active key

| Field | Value |
|---|---|
| Identity | `security@sebastienrousseau.com` |
| Fingerprint | `55AFAD364FD9DB3819E61F0C8D688FAFA9144693` |
| Algorithm | ED25519 primary (sign, certify) + CV25519 encryption subkey |
| Created | 2026-05-16 |
| Expires | 2029-05-15 (3 years from creation; the encryption subkey has no expiry of its own) |
| In-repo copy | [`docs/security/security-pubkey.asc`](security-pubkey.asc) |
| WKD URL | `https://sebastienrousseau.com/.well-known/openpgpkey/hu/t5s8ztdbon8yzntexy6oz5y48etqsnbb` |
| Keyserver | Not published to keys.openpgp.org; use the in-repo copy or WKD. |
| Consistency check | `.github/workflows/verify-gpg-wkd.yml` compares the in-repo key, the WKD key and the pinned fingerprint. This key does not sign commits; commit signing uses separate SSH keys (`KEYS.asc`). |

### Rotation triggers

| Trigger | Response time | Action |
|---|---|---|
| Expiry | Within 30 days of expiry | Generate new key, publish, sign transition statement with the old key, archive old key below. |
| Suspected compromise | Same day | Revoke immediately, publish revocation cert to WKD, replay in-flight encrypted disclosures with the new key. |
| Algorithm deprecation | Within 90 days of advisory | Generate replacement on a stronger algorithm; follow the expiry steps. |
| Maintainer change | Same day as handover | Old maintainer signs a transition statement; old key revoked 30 days after handover. |

### Rotation procedure

1. Generate the new key (air-gapped where possible), with the same
   shape as the active one: an ED25519 primary plus a CV25519
   encryption subkey (reporters encrypt to the subkey):

   ```sh
   gpg --quick-generate-key \
     "Sebastien Rousseau (Dotfiles Security) <security@sebastienrousseau.com>" \
     ed25519 sign,cert 3y
   gpg --quick-add-key <new-fingerprint> cv25519 encr 3y
   ```

2. Sign a transition statement with the OLD key:

   ```sh
   gpg --clearsign <<EOF
   Transition statement, $(date -u +%Y-%m-%dT%H:%M:%SZ).
   The disclosure key for security@sebastienrousseau.com rotates from:
     OLD: <old-fingerprint>
     NEW: <new-fingerprint>
   Encrypted reports sent to either key during the 30-day overlap
   will be accepted. After <UTC-cutoff>, only the new key is honoured.
   EOF
   ```

3. Publish the new key to:
   - `sebastienrousseau.com/.well-known/openpgpkey/hu/` (WKD)
   - `docs/security/security-pubkey.asc` in this repository
   - the maintainer's keyoxide profile if applicable

   Then update the fingerprint pinned in `SECURITY.md` and in
   `.github/workflows/verify-gpg-wkd.yml`, which fails when the three
   disagree.

4. Update the "Active key" table above with the new fingerprint and
   move the previous row into the "Historical disclosure keys"
   table below with the actual revocation date.

5. Commit, signing with both old and new keys during the overlap:

   ```sh
   git commit -S -m "security(key): rotate disclosure key $(date +%Y-%m)" \
     -m "$(cat transition.asc)"
   ```

6. After the 30-day overlap, revoke the old key and publish the
   revocation cert to the same WKD endpoint.

### Historical disclosure keys

| From | Until | Fingerprint | Reason for rotation |
|---|---|---|---|
| *(none yet — first key)* | *—* | *—* | *—* |

---

## Age Key Rotation

### When to Rotate

- **Annually**: As a preventive measure
- **After compromise**: If you suspect key exposure
- **Personnel change**: When team members leave
- **Device loss**: If a device with the key is lost/stolen

### Rotation Procedure

#### 1. Generate New Key

```bash
# Create new age key
age-keygen -o ~/.config/chezmoi/key-new.txt

# Note the public key (starts with "age1...")
cat ~/.config/chezmoi/key-new.txt | grep "public key"
```

#### 2. Re-encrypt All Secrets

```bash
# List all encrypted files
chezmoi managed --include=encrypted

# For each encrypted file, decrypt with old key and re-encrypt with new
for file in $(chezmoi managed --include=encrypted); do
  # Decrypt with old key
  chezmoi cat "$file" > "/tmp/$(basename $file).dec"

  # Re-encrypt with new key (update chezmoi config first)
  # See step 3
done
```

#### 3. Update Chezmoi Configuration

Edit `~/.config/chezmoi/chezmoi.toml`:

```toml
[age]
  identity = "~/.config/chezmoi/key-new.txt"
  recipient = "age1your_new_public_key_here"
```

#### 4. Re-add Encrypted Files

```bash
# Re-add each secret with new encryption
chezmoi add --encrypt ~/.ssh/id_ed25519
chezmoi add --encrypt ~/.config/secrets/api-keys.env
```

#### 5. Verify and Clean Up

```bash
# Verify decryption works
chezmoi cat ~/.ssh/id_ed25519

# Archive old key (store securely offline)
mv ~/.config/chezmoi/key.txt ~/.config/chezmoi/key-$(date +%Y%m%d)-archived.txt

# Rename new key
mv ~/.config/chezmoi/key-new.txt ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt

# Point [age] identity back at the renamed file in chezmoi.toml
# (step 3 set it to key-new.txt, which no longer exists)
#   identity = "~/.config/chezmoi/key.txt"
chezmoi cat ~/.ssh/id_ed25519 >/dev/null && echo "decryption OK"

# Commit changes
cd ~/.dotfiles
git add -A
git commit -m "chore(secrets): rotate age encryption key"
```

### Emergency Rotation (Compromised Key)

```bash
# 1. Immediately generate new key
age-keygen -o ~/.config/chezmoi/key-emergency.txt

# 2. Re-encrypt ALL secrets (prioritize most sensitive)
# 3. Revoke/rotate any API keys, tokens that were encrypted
# 4. Update any shared secrets with team members
# 5. Document the incident
```

---

## SOPS Key Rotation

### Overview

SOPS supports multiple key types. This covers Age keys (recommended) and GPG keys.

### SOPS with Age Keys

#### Generate New Key

```bash
age-keygen -o ~/.config/sops/age/keys-new.txt
```

#### Update .sops.yaml

```yaml
creation_rules:
  - path_regex: \.env$
    age: >-
      age1new_key_here,
      age1old_key_here  # Keep old key temporarily for decryption
```

#### Re-encrypt Files

```bash
# Rotate key for a single file
sops updatekeys secrets.env

# Or re-encrypt entirely
sops -d secrets.env | sops -e /dev/stdin > secrets.env.new
mv secrets.env.new secrets.env
```

#### Remove Old Key

After confirming all files are re-encrypted:

1. Remove old key from `.sops.yaml`
2. Archive old key securely
3. Commit changes

### SOPS with GPG Keys

```bash
# Generate new GPG key
gpg --full-generate-key

# Export fingerprint
gpg --list-keys --keyid-format LONG

# Update .sops.yaml with new fingerprint
# Re-encrypt files
sops updatekeys <file>
```

---

## Automation Scripts

### Check Key Age

```bash
#!/usr/bin/env bash
# check-key-age.sh - Alert if keys are older than 365 days
set -euo pipefail

KEY_FILE="${HOME}/.config/chezmoi/key.txt"
MAX_AGE_DAYS=365

if [[ -f "$KEY_FILE" ]]; then
  key_age=$(( ($(date +%s) - $(stat -c %Y "$KEY_FILE")) / 86400 ))

  if [[ $key_age -gt $MAX_AGE_DAYS ]]; then
    echo "⚠️  Age key is ${key_age} days old. Consider rotation."
    exit 1
  else
    echo "✓ Age key is ${key_age} days old (limit: ${MAX_AGE_DAYS})"
  fi
fi
```

### Automated Backup Before Rotation

```bash
#!/usr/bin/env bash
# backup-before-rotation.sh
set -euo pipefail

BACKUP_DIR="${HOME}/.local/share/dotfiles/key-backups"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# One timestamp for every step: calling date repeatedly can cross a
# second boundary and point the later steps at a file that doesn't exist
ts="$(date +%Y%m%d_%H%M%S)"
plain="$BACKUP_DIR/key-${ts}.txt"

# Backup current key
cp ~/.config/chezmoi/key.txt "$plain"

# Encrypt backup with passphrase (writes "$plain.gpg")
gpg --symmetric --cipher-algo AES256 "$plain"

# Remove unencrypted backup
rm "$plain"

echo "Key backed up to ${plain}.gpg (encrypted)"
```

---

## Best Practices

1. **Never commit unencrypted keys** - Use `.gitignore` properly
2. **Store backups offline** - USB drive in secure location
3. **Use hardware keys when possible** - YubiKey with age-plugin-yubikey
4. **Document rotation dates** - Keep a log of when keys were rotated
5. **Test decryption** - Always verify after rotation
6. **Notify team members** - If using shared secrets

## Recovery Procedures

If you lose access to your key:

1. **Check backups** - Offline storage, password manager
2. **Check other machines** - Key may exist on another device
3. **Re-create secrets** - As last resort, regenerate API keys, tokens, etc.

## Related Documentation

- [SECRETS.md](SECRETS.md) - Secrets management overview
- [SECURITY.md](SECURITY.md) - Security hardening guide
- [Age documentation](https://github.com/FiloSottile/age)
- [SOPS documentation](https://github.com/getsops/sops)
