# Get started

Supported platforms: macOS (Homebrew), Ubuntu/Debian (apt), Arch Linux (pacman), and WSL2.

## Prerequisites

- `git` and `curl`
- Homebrew (macOS), `apt-get` (Linux), or `pacman` (Arch)
- Optional: Docker/Podman (sandbox), Nix (toolchain), `gum` (needed for `dot learn`)

## Install

Works on macOS, Linux, and WSL2:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

### Shell selection

The installer defaults to Zsh. To switch, edit `~/.dotfiles/.chezmoidata.toml`:

```toml
[data]
default_shell = "fish"  # Options: "zsh", "fish", "nu"
```

Then run `dot apply`.

### Feature gating

Toggle features in `.chezmoidata.toml`:

```toml
[features]
zsh = true
fish = true
nushell = true
nix = true
```

### Manual install

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply sebastienrousseau/dotfiles
exec zsh
```

### Using Nix

If you've got Nix with flakes enabled:

```bash
nix develop ~/.dotfiles/nix

# Or install the dot-utils meta-package
nix profile install ~/.dotfiles/nix#dot-utils
```

### Offline / air-gapped

1. **On a connected machine**, bundle your setup:
   ```bash
   dot bundle ~/Downloads
   ```
2. **Transfer** `dotfiles_offline_bundle_*.tar.zst` to the target machine.
3. **Unpack and install** — the installer detects the bundle and skips network calls:
   ```bash
   tar --zstd -xf dotfiles_offline_bundle_*.tar.zst -P
   cd ~/.dotfiles && ./install.sh --force
   ```

### Codespaces and devcontainers

Codespaces auto-detects `.devcontainer/devcontainer.json` and runs `install-full.sh` via `postCreateCommand`. For local devcontainers, open the repo in VS Code Remote Containers — the same hook provisions dotfiles with a server profile.

Environment variables:

- `DOTFILES_PROFILE=server` — headless profile (no GUI tools)
- `DOTFILES_NONINTERACTIVE=1` — non-interactive `chezmoi apply`

## What happens

1. The installer downloads a pinned chezmoi bootstrap, installs OS packages, fonts, and optional apps.
2. Shell config and the `dot` CLI are deployed to `~/.local/bin` and your home directory.
3. Run `dot doctor` to verify everything's working.

## Post-install verification

```bash
dot --version
dot doctor
dot help
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

## Troubleshooting

If install hooks fail, check `~/.local/share/dotfiles.log` and see `docs/TROUBLESHOOTING.md`.
