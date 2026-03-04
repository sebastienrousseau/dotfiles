# Get started

This guide covers supported platforms, prerequisites, and the standard install path.

## Supported platforms

- macOS (Homebrew)
- Ubuntu/Debian (apt)
- WSL2 (Ubuntu/Debian)

## Prerequisites

Required:
- `git`
- `curl`

Optional (feature-dependent):
- Homebrew (macOS)
- `apt-get` (Linux)
- Docker or Podman (sandbox)
- Nix (optional toolchain)
- gum (required for `dot learn`)

## Install

### 1. The Instant Install
Works on macOS, Linux, and WSL2:

```bash
# Works on macOS, Linux, and WSL2
sh -c "$(curl -fsSL https://dotfiles.io/install.sh)"
```

### 2. Post-Install Shell Selection
By default, the installer assumes Zsh. You can choose your preferred shell in `~/.dotfiles/.chezmoidata.toml`:

```toml
[data]
default_shell = "fish"  # Options: "zsh", "fish", "nu"
```

Then apply the change:
```bash
dot apply
```

### 3. Feature Gating
Customize your installation by toggling features in `.chezmoidata.toml`:

```toml
[features]
zsh = true
fish = true
nushell = true
nix = true
```

### Manual installation

```bash
# Clone the repository
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles

# Install chezmoi and apply
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply sebastienrousseau/dotfiles

# Restart shell
exec zsh
```

### Using Nix (alternative)

If you have Nix with flakes enabled:

```bash
# Enter development shell with all tools
nix develop ~/.dotfiles/nix

# Or install the dot-utils meta-package
nix profile install ~/.dotfiles/nix#dot-utils
```

### Offline / Air-Gapped Installation

If you need to install dotfiles on a system without network access:

1. **On a connected machine**, bundle your setup (including your `mise` cache):
   ```bash
   dot bundle ~/Downloads
   ```
2. **Transfer** the `dotfiles_offline_bundle_*.tar.zst` archive to the offline machine.
3. **On the offline machine**, unpack and install:
   ```bash
   tar --zstd -xf dotfiles_offline_bundle_*.tar.zst -P
   cd ~/.dotfiles
   ./install.sh --force
   ```
   *The installer will automatically detect the bundled state and bypass all network calls.*

### Using GitHub Codespaces or devcontainers

```bash
# Codespaces: auto-detects .devcontainer/devcontainer.json
# The postCreateCommand runs install-full.sh automatically

# Local devcontainer (VS Code Remote Containers):
# 1. Open repo in devcontainer
# 2. postCreateCommand provisions dotfiles with server profile
```

Container environment variables:

- `DOTFILES_PROFILE=server` — headless server profile (no GUI tools)
- `DOTFILES_NONINTERACTIVE=1` — non-interactive chezmoi apply

## What happens

1. The installer downloads a pinned Chezmoi bootstrap and applies this repo.
2. Chezmoi hooks install OS packages, fonts, and optional apps.
3. The `dot` CLI becomes available in `~/.local/bin`.
4. Chezmoi symlinks shell configuration to your home directory.

## Post-install verification

```bash
# Check dot CLI is available
dot --version

# Run health checks
dot doctor

# View available commands
dot help
```

## Optional: gum

`gum` is required for interactive features like `dot learn`.

macOS:
```bash
brew install gum
```

Linux (snap):
```bash
sudo snap install gum --classic
```

Linux (Go toolchain):
```bash
go install github.com/charmbracelet/gum@latest
```

## Update

```bash
dot update
```

## Uninstall

```bash
# Remove chezmoi-managed files
chezmoi purge

# Remove the dotfiles repository
rm -rf ~/.dotfiles

# Remove local data
rm -rf ~/.local/share/chezmoi
rm -rf ~/.local/share/dotfiles.log
```

## Troubleshooting

If install hooks fail, check `~/.local/share/dotfiles.log` and review `docs/TROUBLESHOOTING.md`.
