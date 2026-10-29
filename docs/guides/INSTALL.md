---
render_with_liquid: false
---

# Install

Set up on macOS, Linux, or WSL in 3 to 5 minutes.

**You will need:** `git` and `curl`.

**Default shell:** Fish, for the shell Ghostty and Zellij start. Your login shell is not changed unless you ask for it (see below).

## Install

Download and SHA256-verify the release-pinned installer using the canonical
command in the root [README](../../README.md#verified-release-installer), then:

```bash
bash /tmp/dotfiles-install.sh
```

Then restart your terminal or run `exec $SHELL`.

## Verify

```bash
dot --version        # Confirm installation
dot doctor           # Check shell, git, and tools
dot help             # Browse available commands
```

## Choose a shell

Fish is the default shell. To switch to Zsh or Nushell, set `default_shell` in the `[data]` section of this host's `~/.config/chezmoi/chezmoi.toml` (the default lives in `~/.dotfiles/defaults/.chezmoidata.toml`):

```toml
[data]
default_shell = "zsh"
```

Supported values: `zsh`, `fish`, `nu`.

Then apply the change:

```bash
dot apply
```

`default_shell` picks the shell that Ghostty and Zellij launch. To also make Fish or Zsh your login shell, run the installer with `--provision` and `DOTFILES_SET_FISH=1` or `DOTFILES_SET_ZSH=1`, or run `chsh -s "$(command -v zsh)"` yourself.

## Feature flags

Turn optional tools on or off after setup. Override the defaults from `defaults/.chezmoidata.toml` in this host's `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
zellij = true          # Zellij multiplexer config
linux_desktop = true   # Linux desktop / Wayland configs
niri = true            # niri compositor config
ai_theme_sync = false  # Wallpaper-aware AI CLI appearance
```

See [Features](../reference/FEATURES.md) for every flag. Run `dot apply` afterwards.

## Update

```bash
dot update
```

## Next steps

1. Run `dot help tour` to take a guided tour.
2. Add your own tweaks in `~/.zshrc.local` (or files in `~/.config/zsh/rc.d.local/`), `~/.bashrc.local`, or `~/.config/fish/config.fish.local`. They are sourced if present and are not managed by chezmoi.
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

Select the `minimal` profile in this host's `~/.config/chezmoi/chezmoi.toml`
(the tracked source is not edited) and skip toolchain provisioning, even
when `--provision` is also given:

```bash
./install.sh --minimal
```

### Non-interactive install

Use this mode for CI or scripts that run without user input:

```bash
# After the verified download above:
DOTFILES_SILENT=1 DOTFILES_NONINTERACTIVE=1 \
  bash /tmp/dotfiles-install.sh --force
```

### Nix

```bash
nix develop ~/.dotfiles/nix
nix profile install ~/.dotfiles/nix#dot-utils
```

### Offline bundle

On a machine with internet access, create a bundle:

```bash
dot config export ~/Downloads
```

The archive holds `~/.dotfiles`, `~/.config/chezmoi` and `~/.local/share/mise`
(plus the Nix store with `DOTFILES_BUNDLE_NIX=1`). `~/.config/chezmoi` contains
your age key (`key.txt`), so treat the archive as a secret. It stores absolute
paths: extract it as a user with the same home directory path, and note that
extraction overwrites files already at those paths.

Copy the archive to the target machine. Then unpack and install:

```bash
tar --zstd -xf dotfiles_offline_bundle_*.tar.zst -P
cd ~/.dotfiles
./install.sh --force
```

### Uninstall

`chezmoi purge` deletes `~/.config/chezmoi`, which holds your age key
(`key.txt`). Copy the key somewhere safe first if you still need to decrypt
secrets encrypted to it.

```bash
cp ~/.config/chezmoi/key.txt ~/key.txt.backup   # if you use encryption
chezmoi purge
rm -rf ~/.dotfiles
rm -rf ~/.local/share/chezmoi ~/.local/share/dotfiles.log
```

### Signed contributions

All commits must be signed. See [Contributing](https://github.com/sebastienrousseau/dotfiles/blob/main/CONTRIBUTING.md) for details.

---

- [Troubleshooting](TROUBLESHOOTING.md)
- [Support matrix](../reference/SUPPORT_MATRIX.md)
