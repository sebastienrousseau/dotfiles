# Secrets Management

Provider-agnostic secrets via `dot secrets`. Supports macOS Keychain, `pass`, and age-encrypted local storage.

## Providers

Provider selection is controlled by `.chezmoidata.toml`:

```toml
[secrets.policy]
provider = "auto"     # auto | macos-keychain | pass | plain-enc
auto_load = true

[secrets.buckets]
ai = ["GEMINI_API_KEY", "CLAUDE_API_KEY", "OPENAI_API_KEY"]
infra = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "GITHUB_TOKEN"]
```

`auto` resolves in this order:
1. `macos-keychain` on macOS
2. `pass` when available
3. `plain-enc` fallback (age-encrypted local store)

## Commands

```bash
# Bootstrap age key for chezmoi encrypted files
dot secrets-init

# Optional: create encrypted secrets file for chezmoi
dot secrets-create
dot secrets edit

# Managed secret store
dot secrets set GEMINI_API_KEY
dot secrets get GEMINI_API_KEY --raw
dot secrets list
dot secrets provider

# Emit export lines for a bucket
dot secrets load ai

# Load into current shell session
eval "$(dot env load ai)"
```

## Shell Auto-Load

When `auto_load = true`, shell startup can load configured buckets automatically via `dot env load <bucket>`.

Environment toggles:
- `DOTFILES_SECRETS_PROVIDER`
- `DOTFILES_SECRETS_AUTO_LOAD`
- `DOTFILES_SECRETS_BUCKET_NAMES`

## Governance

A pre-commit hook runs:

```bash
scripts/diagnostics/secret-governance.sh
```

It blocks staged commits when likely secret patterns are found. In strict mode it also blocks exact matches against managed secret values.

## SSH Key Encryption

```bash
dot ssh-key ~/.ssh/id_ed25519
```

This creates a local encrypted file, which you can add to chezmoi with `chezmoi add --encrypt` if needed.

## External Secrets Backends

Chezmoi natively supports external secret managers as template functions. Configure the backend in `.chezmoidata.toml`:

```toml
secrets_backend = "age"  # age, 1password, bitwarden, pass, vault
```

### 1Password

Requires the [1Password CLI](https://developer.1password.com/docs/cli/) (`op`).

```toml
# .chezmoidata.toml
secrets_backend = "1password"
```

Use in templates:
```
{{ onepassword "my-secret" "vault-name" }}
{{ onepasswordRead "op://vault/item/field" }}
```

### Bitwarden

Requires the [Bitwarden CLI](https://bitwarden.com/help/cli/) (`bw`).

```toml
# .chezmoidata.toml
secrets_backend = "bitwarden"
```

Use in templates:
```
{{ bitwarden "item" "my-login" }}
{{ bitwardenFields "item" "my-login" }}
```

### HashiCorp Vault

Requires the [Vault CLI](https://developer.hashicorp.com/vault/docs/commands) (`vault`).

```toml
# .chezmoidata.toml
secrets_backend = "vault"
```

Use in templates:
```
{{ vault "secret/data/my-secret" }}
```

### pass (Password Store)

Requires [pass](https://www.passwordstore.org/).

```toml
# .chezmoidata.toml
secrets_backend = "pass"
```

Use in templates:
```
{{ pass "my-secret" }}
```

See the [chezmoi documentation](https://www.chezmoi.io/user-guide/password-managers/) for full details on each backend.

## Security Notes

- **Never commit** `~/.config/chezmoi/key.txt` to version control.
- **Avoid shell history exposure** — use `dot secrets set` which prompts securely.
- **Rotate credentials** on a regular schedule.
