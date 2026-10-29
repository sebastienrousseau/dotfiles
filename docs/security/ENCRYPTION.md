---
render_with_liquid: false
---

# Secrets Encryption with SOPS and age

## Quick Start

```bash
# 1. Generate an age key (one-time)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# 2. Get your public key
age-keygen -y ~/.config/sops/age/keys.txt
# Output: age1abc123...

# 3. Update .sops.yaml with your public key
# Replace the placeholder key in .sops.yaml with your actual public key

# 4. Encrypt a file
sops --encrypt --age $(age-keygen -y ~/.config/sops/age/keys.txt) secrets.yaml > secrets.sops.yaml

# 5. Edit encrypted files
sops secrets.sops.yaml
```

## Key Management

- **Private key**: `~/.config/sops/age/keys.txt` — never commit this file.
- **Public key**: Safe to share. It lives in `.sops.yaml`.
- **Backup**: Keep your private key in a password manager or a hardware security module.

## Recovery

If you lose your age private key and have no backup, files encrypted to it
cannot be decrypted, so they cannot be re-encrypted either. Recover by
replacing the secrets themselves:

1. Create a new key: `age-keygen -o ~/.config/sops/age/keys.txt`
2. Update `.sops.yaml` with the new public key.
3. Regenerate or re-fetch each secret at its source (rotate API keys and
   tokens with their providers), then encrypt the new values with the new
   key. Delete the old encrypted files.

If any machine still holds the old key, decrypt there and re-encrypt to
the new key instead (see [KEY_ROTATION.md](KEY_ROTATION.md)).

## Integration with Chezmoi

Chezmoi has built-in support for age encryption.

```bash
chezmoi add --encrypt ~/.ssh/config
```

This encrypts the file in the source state. It uses the age key set in `~/.config/chezmoi/chezmoi.toml`. The dotfiles config template defaults the
identity to `~/.config/chezmoi/key.txt` (the key `dot secret init`
creates), separate from the SOPS key above:

```toml
encryption = "age"
[age]
identity = "~/.config/chezmoi/key.txt"
recipient = "age1abc123..."
```
