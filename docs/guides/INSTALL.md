# Install

Install on macOS, Linux, or WSL in 3-5 minutes.

**Prerequisites:** `git` and `curl`.

**Default shell:** Fish (change it after installation).

## Install

```bash
bash -c "$(
  curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh
)"
```

Then restart the terminal or run `exec $SHELL`.

## Verify

```bash
dot --version        # Confirm installation
dot doctor           # Check shell, git, and tools
dot help             # Browse available commands
```

## Choose a shell

The default shell is Fish. Switch to Zsh or Nushell by editing `~/.dotfiles/.chezmoidata.toml`:

```toml
default_shell = "zsh"
```

Supported values: `zsh`, `fish`, `nushell`.

Apply the change:

```bash
dot apply
```

## Feature flags

Toggle optional tools after initial setup. Edit `.chezmoidata.toml`:

```toml
[features]
zsh = true         # Zsh shell configuration
fish = true        # Fish shell configuration
nushell = true     # Nushell configuration
nvim = true        # Neovim IDE configuration
tmux = true        # Terminal multiplexer
nix = true         # Nix package manager integration
```

## Update

```bash
dot update
```

## Next steps

1. Run `dot learn` for an interactive onboarding tour.
2. Customize files in `~/.config/shell/custom/`.
3. Read the [Utilities and `dot` CLI](../reference/UTILS.md) reference.

---

## Advanced

### Local source install

Clone first, then run the installer from the local source tree:

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

### Minimal install

Install shells and essentials only (skip editor and terminal extras):

```bash
./install.sh --minimal
```

### Non-interactive install

For CI or automation:

```bash
DOTFILES_SILENT=1 DOTFILES_NONINTERACTIVE=1 \
  bash -c "$(
    curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh
  )"
```

### Nix

```bash
nix develop ~/.dotfiles/nix
nix profile install ~/.dotfiles/nix#dot-utils
```

### Offline bundle

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

### Uninstall

```bash
chezmoi purge
rm -rf ~/.dotfiles
rm -rf ~/.local/share/chezmoi ~/.local/share/dotfiles.log
```

### Signed contributions

Signed commits are required. See [Contributing](../../CONTRIBUTING.md).

---

- [Troubleshooting](TROUBLESHOOTING.md)
- [Support matrix](../reference/SUPPORT_MATRIX.md)
