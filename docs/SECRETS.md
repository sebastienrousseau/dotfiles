# Secrets

Dotfiles supports provider-agnostic secret management through `dot secrets`.

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

## Important Notes

- Never commit `~/.config/chezmoi/key.txt`.
- Keep secret values out of shell history when possible.
- Rotate keys and credentials periodically.
