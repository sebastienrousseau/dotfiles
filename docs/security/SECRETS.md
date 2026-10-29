---
render_with_liquid: false
---
{% raw %}

# Secrets Management

Provider-agnostic secrets via `dot secret`. Supports macOS Keychain, `pass`, and age-encrypted local storage.

## Providers

Provider selection can be set in `.chezmoidata.toml`. The shipped file has
no `[secrets.policy]` table; without one (and without
`DOTFILES_SECRETS_PROVIDER`), the provider is `auto`. To pin it, add:

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
3. `plain-enc` (age-encrypted local store) when `age` is installed and the age key exists

## Commands

```bash
# Bootstrap age key for chezmoi encrypted files
dot secret init

# Optional: create encrypted secrets file for chezmoi
dot secret new
dot secret edit

# Managed secret store
dot secret set GEMINI_API_KEY
dot secret show GEMINI_API_KEY --raw
dot secret list
dot secret provider show

# Emit export lines for a bucket
dot secret export ai

# Load into current shell session
eval "$(dot secret export ai)"
```

## Shell Auto-Load

When `auto_load = true`, shell startup can load configured buckets automatically via `dot secret export <bucket>`.

Environment toggles:

- `DOTFILES_SECRETS_PROVIDER`
- `DOTFILES_SECRETS_AUTO_LOAD`
- `DOTFILES_SECRETS_BUCKET_NAMES`

## Governance

`scripts/diagnostics/secret-governance.sh` scans for likely secret
patterns. It runs:

- on demand, as `dot secret check`
- as a pre-commit hook in this repository, once the repository hooks are
  installed with `scripts/git-hooks/install.sh` (it is not part of the
  `pre-commit` framework config, so `pre-commit install` does not add it)

As a hook it blocks staged commits when likely secret patterns are found. In strict mode it also blocks exact matches against managed secret values.

## SSH Key Encryption

```bash
dot secret key new ~/.ssh/id_ed25519
```

This creates a local encrypted file, which you can add to chezmoi with `chezmoi add --encrypt` if needed.

## External Secrets Backends

Chezmoi natively supports external secret managers as template functions.
No dotfiles setting selects a backend: install the manager's CLI, sign in,
and call its template function from a `.tmpl` file.

### 1Password

Requires the [1Password CLI](https://developer.1password.com/docs/cli/) (`op`).

Use in templates:

```text
{{ onepassword "my-secret" "vault-name" }}
{{ onepasswordRead "op://vault/item/field" }}
```

### Bitwarden

Requires the [Bitwarden CLI](https://bitwarden.com/help/cli/) (`bw`).

Use in templates:

```text
{{ bitwarden "item" "my-login" }}
{{ bitwardenFields "item" "my-login" }}
```

### HashiCorp Vault

Requires the [Vault CLI](https://developer.hashicorp.com/vault/docs/commands) (`vault`).

Use in templates:

```text
{{ vault "secret/data/my-secret" }}
```

### pass (Password Store)

Requires [pass](https://www.passwordstore.org/).

Use in templates:

```text
{{ pass "my-secret" }}
```

See the [chezmoi documentation](https://www.chezmoi.io/user-guide/password-managers/) for full details on each backend.

## Security Notes

- **Never commit** `~/.config/chezmoi/key.txt` to version control.
- **Avoid shell history exposure** — use `dot secret set` which prompts securely.
- **Rotate credentials** on a regular schedule.
{% endraw %}
