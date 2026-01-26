# Secrets

This repo supports encrypted secrets using `age` with `chezmoi`.

## Get started

```bash
dot secrets-init
```

This creates `~/.config/chezmoi/key.txt` and prints your public key.
It also updates `~/.config/chezmoi/chezmoi.toml` with the age backend settings.

Verify that `age` is installed first (via brew/apt or your toolchain).

## Enable encryption

Edit `~/.config/chezmoi/chezmoi.toml` (local only):

```toml
encryption = "age"

[age]
identity = "~/.config/chezmoi/key.txt"
recipient = "age1..."
```

You can also re-run:

```bash
chezmoi init --apply --promptDefaults
```

## Edit

```bash
dot secrets
```

This edits `~/.config/chezmoi/encrypted_secrets.age` and applies on save.

## Create

```bash
dot secrets-create
```

Then edit:

```bash
dot secrets
```

## Encrypt an SSH key

```bash
dot ssh-key ~/.ssh/id_ed25519
```

This creates a local encrypted file at:
`~/.config/chezmoi/encrypted_id_ed25519.age`

If you want it tracked (encrypted) in your dotfiles, run:

```bash
chezmoi add --encrypt ~/.config/chezmoi/encrypted_id_ed25519.age
```

## Notes
- Keep `~/.config/chezmoi/key.txt` private.
- You can share the public key for encrypting data.
- Consider rotating keys yearly (or after any potential leak).
  Steps: generate a new key, update `chezmoi.toml`, re-encrypt secrets, delete old key.
