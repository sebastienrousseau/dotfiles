# Key Rotation Guide

This guide covers rotating encryption keys for secrets managed by Age and SOPS.

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

BACKUP_DIR="${HOME}/.local/share/dotfiles/key-backups"
mkdir -p "$BACKUP_DIR"

# Backup current key
cp ~/.config/chezmoi/key.txt "$BACKUP_DIR/key-$(date +%Y%m%d_%H%M%S).txt"

# Encrypt backup with passphrase
gpg --symmetric --cipher-algo AES256 "$BACKUP_DIR/key-$(date +%Y%m%d_%H%M%S).txt"

# Remove unencrypted backup
rm "$BACKUP_DIR/key-$(date +%Y%m%d_%H%M%S).txt"

echo "Key backed up to $BACKUP_DIR (encrypted)"
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
