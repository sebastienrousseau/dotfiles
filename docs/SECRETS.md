# Secrets (age + chezmoi)

This repo supports encrypted secrets using `age` with `chezmoi`.

## Initialize

```bash
dot secrets-init
```

This creates `~/.config/chezmoi/key.txt` and prints your public key.

## Edit secrets

```bash
dot secrets
```

This edits `~/.config/chezmoi/encrypted_secrets.age` and applies on save.

## Notes
- Keep `~/.config/chezmoi/key.txt` private.
- You can share the public key for encrypting data.
