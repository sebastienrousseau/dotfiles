# Secrets

You can encrypt secrets using `age` with `chezmoi`.

## Get started

```bash
dot secrets-init
```

The command creates `~/.config/chezmoi/key.txt` and prints your public key. It also updates `~/.config/chezmoi/chezmoi.toml` with the `age` backend settings.

> [!IMPORTANT]
> Verify that `age` is installed before running this command. You can install it through `brew`, `apt`, or your preferred toolchain.

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

## Edit secrets

```bash
dot secrets
```

The command opens `~/.config/chezmoi/encrypted_secrets.age` for editing and applies changes when you save.

## Create secrets

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

The command creates a local encrypted file at:
`~/.config/chezmoi/encrypted_id_ed25519.age`

If you want it tracked (encrypted) in your dotfiles, run:

```bash
chezmoi add --encrypt ~/.config/chezmoi/encrypted_id_ed25519.age
```

## Important notes

> [!WARNING]
> Keep `~/.config/chezmoi/key.txt` private. Never commit this file to a public repository.

- You can share the public key freely for encrypting data.
- Consider rotating keys yearly (or after any potential leak).
  To rotate: generate a new key, update `chezmoi.toml`, re-encrypt your secrets, and delete the old key.
