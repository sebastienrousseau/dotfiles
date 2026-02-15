# Get Started

This guide shows the supported platforms, prerequisites, and the standard install path.

## Supported Platforms

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

### One-Liner (Recommended)

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
exec zsh
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles

# Install chezmoi and apply
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply sebastienrousseau/dotfiles

# Restart shell
exec zsh
```

### Using Nix (Alternative)

If you have Nix with flakes enabled, enter a development shell after cloning the repository:

```bash
# First, clone the repository if you haven't already
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles

# Enter development shell with all tools
nix develop ~/.dotfiles/nix

# Or install the dot-utils meta-package
nix profile install ~/.dotfiles/nix#dot-utils
```

## What Happens

1. The installer downloads a pinned Chezmoi bootstrap and applies this repo.
2. Chezmoi hooks install OS packages, fonts, and optional apps.
3. The `dot` CLI becomes available in `~/.local/bin`.
4. Chezmoi symlinks shell configuration to your home directory.

## Post-Install Verification

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
