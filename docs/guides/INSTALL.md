# Install

Set up on macOS, Linux, or WSL in 3 to 5 minutes.

**You will need:** `git` and `curl`.

**Default shell:** Fish. You can change it after you install.

## Install

```bash
bash -c "$(
  curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh
)"
```

Then restart your terminal or run `exec $SHELL`.

## Verify

```bash
dot --version        # Confirm installation
dot doctor           # Check shell, git, and tools
dot help             # Browse available commands
```

## Choose a shell

Fish is the default shell. To switch to Zsh or Nushell, edit `~/.dotfiles/.chezmoidata.toml`:

```toml
default_shell = "zsh"
```

Supported values: `zsh`, `fish`, `nushell`.

Then apply the change:

```bash
dot apply
```

## Feature flags

Turn optional tools on or off after setup. Edit `.chezmoidata.toml`:

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

1. Run `dot learn` to take a guided tour.
2. Add your own tweaks in `~/.config/shell/custom/`.
3. Read the [Utilities and `dot` CLI](../reference/UTILS.md) reference.

---

## Advanced

### Local source install

Clone the repo first, then run the installer from your local copy:

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

### Minimal install

Install only shells and core tools. This skips editor and terminal extras:

```bash
./install.sh --minimal
```

### Non-interactive install

Use this mode for CI or scripts that run without user input:

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

On a machine with internet access, create a bundle:

```bash
dot bundle ~/Downloads
```

Copy the archive to the target machine. Then unpack and install:

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

All commits must be signed. See [Contributing](../../CONTRIBUTING.md) for details.

---

- [Troubleshooting](TROUBLESHOOTING.md)
- [Support matrix](../reference/SUPPORT_MATRIX.md)
