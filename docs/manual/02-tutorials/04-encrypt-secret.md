# Tutorial: Encrypt a Secret

How to store an API key (or any secret) encrypted in the repository using Age and SOPS — decrypted automatically on `dot apply`.

## The Threat Model

Secrets in plaintext config files are:

- Committed to Git history (permanent record)
- Visible to every process on the machine
- Included in backup archives

Secrets encrypted with Age:

- Cipher text committed to Git is useless without the private key
- Private key (`~/.config/age/keys.txt`) never leaves the user's machine
- Per-machine policy: only authorized hosts hold keys for their share of secrets

## Step 1: Generate an Age Key (First Time Only)

```sh
age-keygen -o ~/.config/age/keys.txt
chmod 600 ~/.config/age/keys.txt
```

The public key is embedded in the file:

```sh
cat ~/.config/age/keys.txt
# created: 2026-04-16T09:00:00Z
# public key: age1qy90l...xyz
AGE-SECRET-KEY-1A...
```

Copy the public key — you'll reference it when encrypting.

## Step 2: Choose Encryption Method

Two approaches are supported:

| Method | Best For | Filename |
|:---|:---|:---|
| **Chezmoi encrypt** | Individual files (API tokens, config snippets) | `dot_config/token.age` |
| **SOPS** | YAML/JSON with multiple secrets, selective field encryption | `dot_config/creds.sops.yaml` |

## Step 3A: Chezmoi-Encrypted File

Create an unencrypted source file:

```sh
mkdir -p ~/tmp
echo "sk_live_abc123" > ~/tmp/stripe-key.txt
```

Import it as encrypted:

```sh
chezmoi add --encrypt ~/tmp/stripe-key.txt
```

This:

1. Reads `~/tmp/stripe-key.txt`
2. Encrypts with your Age public key
3. Stores encrypted content at `~/.dotfiles/dot_tmp/stripe-key.txt.age`
4. Template reads encrypted content at apply time and decrypts to target

Delete the plaintext source:

```sh
rm ~/tmp/stripe-key.txt
```

On `dot apply`, chezmoi decrypts and writes to `~/tmp/stripe-key.txt`. If someone lacks the private key, they see only the encrypted `.age` file in Git.

## Step 3B: SOPS-Encrypted YAML

SOPS encrypts **values** in YAML/JSON while preserving the structure. Useful when you want:

- Multiple secrets in one file
- Encryption of only sensitive fields (leaving metadata readable)
- Multi-recipient (e.g. the work laptop AND the backup laptop can decrypt)

Configure SOPS once:

```yaml
# .sops.yaml (at repo root)
creation_rules:
  - path_regex: \.sops\.yaml$
    age: age1qy90l...xyz
```

Create a secrets file:

```yaml
# dot_config/credentials.sops.yaml
database:
  host: db.prod.example.com
  user: app
  password: supersecret
api_keys:
  stripe: sk_live_abc
  sendgrid: SG.xyz
```

Encrypt it:

```sh
sops --encrypt --in-place dot_config/credentials.sops.yaml
```

The file now contains ciphertext blobs where plaintext values were:

```yaml
database:
    host: ENC[AES256_GCM,data:...]
    user: ENC[AES256_GCM,data:...]
    password: ENC[AES256_GCM,data:...]
api_keys:
    stripe: ENC[AES256_GCM,data:...]
    sendgrid: ENC[AES256_GCM,data:...]
sops:
    age:
        - recipient: age1qy90l...xyz
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
```

To edit the encrypted file:

```sh
sops dot_config/credentials.sops.yaml
# Opens in $EDITOR with decrypted content; re-encrypts on save
```

## Step 4: Reference the Secret in a Template

Chezmoi has a built-in `decrypt` helper:

```go
# dot_bashrc.tmpl
export STRIPE_KEY="{{ include "dot_tmp/stripe-key.txt.age" | decrypt | trim }}"
```

For SOPS:

```go
# Use the sopsDecrypt template function
{{- $creds := dict -}}
{{- $creds = sopsDecrypt "dot_config/credentials.sops.yaml" | fromYaml }}
export DB_PASSWORD="{{ $creds.database.password }}"
```

## Step 5: Commit and Verify

```sh
cd ~/.dotfiles
git add .sops.yaml dot_config/credentials.sops.yaml dot_tmp/stripe-key.txt.age
git commit -sS -m "feat(secrets): add stripe and database credentials"
git push
```

Verify the commit doesn't leak secrets:

```sh
git log -p HEAD~1..HEAD | grep -v ENC | grep -iE 'password|secret|key' || echo "Clean"
```

On the next machine:

```sh
dot update
# Chezmoi decrypts using that machine's Age key
# If decryption fails, the template errors with a clear message
```

## Step 6: Multi-Recipient (Fleet)

To allow multiple hosts to decrypt the same secret, add more recipients:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: \.sops\.yaml$
    age: >-
      age1qy90l...xyz,
      age1z2x33...abc,
      age1mm0kk...def
```

Re-encrypt the affected files:

```sh
sops updatekeys dot_config/credentials.sops.yaml
```

Now any host with one of those three private keys can decrypt. Hosts without any matching key see the encrypted file but cannot read it.

## Step 7: Rotate a Compromised Key

```sh
# 1. Generate a new Age key on the affected host
age-keygen -o ~/.config/age/keys.txt.new
mv ~/.config/age/keys.txt.new ~/.config/age/keys.txt

# 2. Update .sops.yaml with the new public key

# 3. Re-encrypt all SOPS files with the new recipient list
find . -name '*.sops.yaml' -exec sops updatekeys {} \;

# 4. Commit and push
git add .sops.yaml dot_config/*.sops.yaml
git commit -sS -m "chore(secrets): rotate Age key"

# 5. On other fleet hosts
dot update
```

Old key still works for existing ciphertext, but new secrets use the new key. To force deprecation, delete the old key from `.sops.yaml` and `sops updatekeys` all files.

## Verifying No Plaintext Leaks

CI runs three secret scanners (`gitleaks`, `detect-secrets`, `trufflehog`) on every commit. You can run them locally:

```sh
gitleaks detect --redact --source .
detect-secrets scan --update .secrets.baseline
trufflehog git file://. --only-verified
```

If any scanner finds a potential leak, the commit is blocked.

## Operational Rules

1. **Never commit plaintext secrets** — use chezmoi encrypt or SOPS
2. **Never commit `~/.config/age/keys.txt`** — it's gitignored; double-check before pushing
3. **Age keys are per-host** — don't copy them via Git; use secure channels (1Password, Bitwarden, physical USB)
4. **Rotate on team membership changes** — when someone leaves, update recipients and rotate all shared secrets
5. **Audit with `dot verify --security`** — runs gitleaks + signature + policy hash checks

## Troubleshooting

### "Could not decrypt: no age key found"

`~/.config/age/keys.txt` is missing or unreadable:

```sh
chmod 600 ~/.config/age/keys.txt
ls -la ~/.config/age/keys.txt
# -rw------- 1 user user 189 Apr 16 09:00 keys.txt
```

### "sops: file encrypted with outdated recipients"

A secret file has an old recipient list. Fix:

```sh
sops updatekeys path/to/file.sops.yaml
```

### Secrets Not Applying After Apply

Check that `dot_tmp/stripe-key.txt.age` is committed. Run:

```sh
chezmoi apply --verbose dot_tmp/stripe-key.txt
# Will show decrypt attempts and errors
```

## Next

- [Concept: Trust Model](../01-concepts/02-trust-model.md) — the security architecture
- [Reference: Secret operations](../03-reference/01-dot-cli.md#secrets)
- [Security: Secret management](../../security/SECRETS.md)
