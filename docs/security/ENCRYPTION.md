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

- **Private key**: `~/.config/sops/age/keys.txt` (NEVER commit this)
- **Public key**: Safe to share, stored in `.sops.yaml`
- **Backup**: Store private key in a password manager or hardware security module

## Recovery

If you lose your age private key:
1. Re-generate: `age-keygen -o ~/.config/sops/age/keys.txt`
2. Re-encrypt all secrets with the new public key
3. Update `.sops.yaml` with the new public key

## Integration with Chezmoi

Chezmoi supports age encryption natively:

```bash
chezmoi add --encrypt ~/.ssh/config
```

This encrypts the file in the source state using the age key configured in `~/.config/chezmoi/chezmoi.toml`:

```toml
encryption = "age"
[age]
identity = "~/.config/sops/age/keys.txt"
recipient = "age1abc123..."
```
