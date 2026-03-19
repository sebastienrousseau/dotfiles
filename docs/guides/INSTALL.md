# Install

Install on macOS, Linux, or WSL in a few minutes.

## Prerequisites

- `git`
- `curl`

Optional:
- Docker or Podman for sandbox use
- Nix for reproducible toolchains

## Standard install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
```

## Verify

```bash
dot --version
dot doctor
dot help
```

## Choose a shell

The default shell is Zsh.

Set a different shell in `~/.dotfiles/.chezmoidata.toml`:

```toml
[data]
default_shell = "fish"
```

Supported values:
- `zsh`
- `fish`
- `nu`

Apply the change:

```bash
dot apply
```

## Feature flags

Toggle features in `.chezmoidata.toml`:

```toml
[features]
zsh = true
fish = true
nushell = true
nix = true
```

## Local source install

Clone first. Then run the installer from the local source tree.

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Minimal install

Skip editor and terminal extras:

```bash
./install.sh --minimal
```

## Non-interactive install

```bash
DOTFILES_SILENT=1 DOTFILES_NONINTERACTIVE=1 \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
```

## Nix

```bash
nix develop ~/.dotfiles/nix
nix profile install ~/.dotfiles/nix#dot-utils
```

## Offline bundle

Create a bundle on a connected machine:

```bash
dot bundle ~/Downloads
```

Transfer the archive. Then unpack and install:

```bash
tar --zstd -xf dotfiles_offline_bundle_*.tar.zst -P
cd ~/.dotfiles
./install.sh --force
```

## Update

```bash
dot update
```

## Uninstall

```bash
chezmoi purge
rm -rf ~/.dotfiles
rm -rf ~/.local/share/chezmoi ~/.local/share/dotfiles.log
```

## Signed contributions

Signed commits are required for changes to this repo.

See [Contributing](../../CONTRIBUTING.md).

## Next steps

- [Utilities and `dot` CLI](../reference/UTILS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Support matrix](../reference/SUPPORT_MATRIX.md)
