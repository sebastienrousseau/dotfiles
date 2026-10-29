---
render_with_liquid: false
---
{% raw %}

# Tutorial: Encrypt a Secret

How to store an API key (or any secret) encrypted in the repository using Age and SOPS, decrypted on `dot apply`.

## The Threat Model

Secrets in plaintext config files are:

- Committed to Git history (permanent record)
- Visible to every process on the machine
- Included in backup archives

Secrets encrypted with Age:

- Cipher text committed to Git is useless without the private key
- The private key (`~/.config/chezmoi/key.txt`) lives outside the repository and never leaves the user's machine
- Per-machine policy: only authorized hosts hold keys for their share of secrets

## Step 1: Generate an Age Key (First Time Only)

```sh
dot secret init
```

This creates `~/.config/chezmoi/key.txt` (mode 600) with `age-keygen`, if it does not exist yet, and writes `encryption = "age"` and an `[age]` table with that `identity` and its public key as `recipient` to `~/.config/chezmoi/chezmoi.toml`.

The public key is in the file's header:

```sh
age-keygen -y ~/.config/chezmoi/key.txt
# age1...
```

Copy the public key: SOPS needs it in Step 3B.

## Step 2: Choose Encryption Method

Two approaches are supported. Source paths are relative to `~/.dotfiles/defaults/`, the chezmoi source root (`.chezmoiroot`).

| Method | Best For | Source File |
|:---|:---|:---|
| **Chezmoi encrypt** | Individual files (API tokens, config snippets) | `tmp/encrypted_stripe-key.txt.age` |
| **SOPS** | YAML/JSON with multiple secrets, selective field encryption | `.secrets/credentials.sops.yaml` |

## Step 3A: Chezmoi-Encrypted File

Create an unencrypted file at the place it should end up:

```sh
mkdir -p ~/tmp
echo "sk_live_abc123" > ~/tmp/stripe-key.txt
```

Add it encrypted:

```sh
chezmoi add --encrypt ~/tmp/stripe-key.txt
```

This:

1. Reads `~/tmp/stripe-key.txt`
2. Encrypts it to the `recipient` in `~/.config/chezmoi/chezmoi.toml`
3. Stores the ciphertext at `~/.dotfiles/defaults/tmp/encrypted_stripe-key.txt.age`

The target file stays in place: chezmoi now manages it. On `dot apply`, chezmoi decrypts the source with `~/.config/chezmoi/key.txt` and writes `~/tmp/stripe-key.txt`. Anyone without the private key sees only the encrypted `.age` file in Git.

## Step 3B: SOPS-Encrypted YAML

SOPS encrypts **values** in YAML/JSON while preserving the structure. Useful when you want:

- Multiple secrets in one file
- Encryption of only sensitive fields (leaving metadata readable)
- Multiple recipients (e.g. the work laptop AND the backup laptop can decrypt)

SOPS reads its rules from the `.sops.yaml` at the repository root. Its age key is a **non-functional placeholder**: replace it with your public key from Step 1 before encrypting anything:

```yaml
# ~/.dotfiles/.sops.yaml
creation_rules:
  - path_regex: .*\.sops\.ya?ml$
    key_groups:
      - age:
          - age1...   # your public key
```

SOPS looks for its private key in `~/.config/sops/age/keys.txt` by default. To use the chezmoi key instead:

```sh
export SOPS_AGE_KEY_FILE=~/.config/chezmoi/key.txt
```

Create a secrets file. Chezmoi ignores source entries whose name starts with `.`, so a file under `.secrets/` is never deployed itself:

```yaml
# ~/.dotfiles/defaults/.secrets/credentials.sops.yaml
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
cd ~/.dotfiles/defaults
sops --encrypt --in-place .secrets/credentials.sops.yaml
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
        - recipient: age1...
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
```

To edit the encrypted file:

```sh
sops .secrets/credentials.sops.yaml
# Opens in $EDITOR with decrypted content; re-encrypts on save
```

## Step 4: Reference the Secret in a Template

Chezmoi's `decrypt` template function decrypts an age file from the source directory:

```go
# ~/.dotfiles/defaults/dot_config/myapp/env.tmpl
export STRIPE_KEY="{{ include "tmp/encrypted_stripe-key.txt.age" | decrypt | trim }}"
```

Chezmoi has no SOPS template function. Run `sops` through `output` instead:

```go
{{- $creds := output "sops" "--decrypt" (joinPath .chezmoi.sourceDir ".secrets/credentials.sops.yaml") | fromYaml }}
export DB_PASSWORD="{{ $creds.database.password }}"
```

`sops` must find a private key when chezmoi renders the template (see `SOPS_AGE_KEY_FILE` above).

## Step 5: Commit and Verify

Stage the encrypted files and check the staged content before committing:

```sh
cd ~/.dotfiles
git add .sops.yaml defaults/.secrets/credentials.sops.yaml defaults/tmp/encrypted_stripe-key.txt.age
dot secret check
git commit -sS -m "feat(secrets): add stripe and database credentials"
git push
```

`dot secret check` scans the staged content for plaintext secret patterns and for the values of managed secrets, and prints `Secret governance passed.` when it finds none.

On the next machine:

```sh
dot config update
# Pulls the source and applies; chezmoi decrypts with that machine's age key
# If decryption fails, apply stops with chezmoi's error
```

## Step 6: Multi-Recipient (Fleet)

To allow multiple hosts to decrypt the same SOPS file, add more recipients:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: .*\.sops\.ya?ml$
    key_groups:
      - age:
          - age1...   # laptop
          - age1...   # desktop
          - age1...   # backup laptop
```

Re-encrypt the affected files:

```sh
sops updatekeys defaults/.secrets/credentials.sops.yaml
```

Now any host with one of those three private keys can decrypt. Hosts without any matching key see the encrypted file but cannot read it.

For chezmoi-encrypted files, chezmoi's `[age]` table takes a `recipients` list in place of `recipient`; re-add each file with `chezmoi add --encrypt` after changing it.

## Step 7: Rotate a Compromised Key

```sh
# 1. Generate a new age key next to the old one
age-keygen -o ~/.config/chezmoi/key-new.txt
chmod 600 ~/.config/chezmoi/key-new.txt

# 2. In .sops.yaml, replace the old public key with the new one, then
#    re-encrypt each SOPS file (the old key is still needed to decrypt)
SOPS_AGE_KEY_FILE=~/.config/chezmoi/key.txt sops updatekeys defaults/.secrets/credentials.sops.yaml
SOPS_AGE_KEY_FILE=~/.config/chezmoi/key-new.txt sops rotate --in-place defaults/.secrets/credentials.sops.yaml

# 3. Point chezmoi at the new key: in ~/.config/chezmoi/chezmoi.toml set
#    [age] recipient to the new public key, then re-add each encrypted file
chezmoi add --encrypt ~/tmp/stripe-key.txt

# 4. Swap the key files and commit
mv ~/.config/chezmoi/key-new.txt ~/.config/chezmoi/key.txt
git add .sops.yaml defaults/
git commit -sS -m "chore(secrets): rotate age key"

# 5. On other hosts
dot config update
```

`sops updatekeys` changes who can decrypt; `sops rotate` also replaces the data key, so a leaked copy of the old key cannot decrypt the new ciphertext. Secrets that the old key could read should still be treated as exposed: rotate them at their source too.

## Verifying No Plaintext Leaks

The pre-commit hooks run `gitleaks` and `detect-secrets` on every commit, and CI runs `gitleaks` and `trufflehog`. You can run them locally:

```sh
cd ~/.dotfiles
pre-commit run gitleaks --all-files
pre-commit run detect-secrets --all-files
trufflehog git file://. --only-verified
```

If a hook finds a potential leak, the commit is blocked; in CI, the check fails.

## Operational Rules

1. **Never commit plaintext secrets**: use chezmoi encrypt or SOPS
2. **Never commit `~/.config/chezmoi/key.txt`**: it lives outside the repository; keep it that way
3. **Age keys are per-host**: don't copy them via Git; use secure channels (1Password, Bitwarden, physical USB)
4. **Rotate on team membership changes**: when someone leaves, update recipients and rotate all shared secrets
5. **Audit staged changes with `dot secret check`** before each commit that touches secrets

## Troubleshooting

### "no identity" or decryption errors on apply

`~/.config/chezmoi/key.txt` is missing or unreadable, or `[age] identity` in `~/.config/chezmoi/chezmoi.toml` points elsewhere:

```sh
ls -la ~/.config/chezmoi/key.txt    # should be -rw------- and owned by you
chmod 600 ~/.config/chezmoi/key.txt
```

`dot secret init` recreates the `[age]` table for the existing key.

### SOPS cannot decrypt

The file's recipient list does not include your key, or SOPS cannot find the private key. Check `SOPS_AGE_KEY_FILE`, then update the recipients from a host that can decrypt:

```sh
sops updatekeys path/to/file.sops.yaml
```

### Secrets Not Applying After Apply

Check that `defaults/tmp/encrypted_stripe-key.txt.age` is committed and pulled. Then:

```sh
chezmoi apply --verbose ~/tmp/stripe-key.txt
# Shows the diff it applies, or the decryption error
```

## Next

- [Concept: Trust Model](../01-concepts/02-trust-model.md): the security architecture
- [Reference: Secret operations](../03-reference/01-dot-cli.md#dot-secret)
- [Security: Secret management](../../security/SECRETS.md)
{% endraw %}
