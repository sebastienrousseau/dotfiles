# Secrets (age + chezmoi)

This repo supports encrypted secrets using `age` with `chezmoi`.

## Initialize

```bash
dot secrets-init
```

This creates `~/.config/chezmoi/key.txt` and prints your public key.

## Enable encryption in chezmoi

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

## Edit secrets

```bash
dot secrets
```

This edits `~/.config/chezmoi/encrypted_secrets.age` and applies on save.

## Create a new secrets file (first time)

```bash
chezmoi edit --apply ~/.config/chezmoi/encrypted_secrets.age
```

Add key=value pairs, save, and chezmoi will store the encrypted file in your
dotfiles source (never plaintext).

## Notes
- Keep `~/.config/chezmoi/key.txt` private.
- You can share the public key for encrypting data.
 - Consider rotating keys yearly (or after any potential leak).
   Steps: generate a new key, update `chezmoi.toml`, re-encrypt secrets, delete old key.
