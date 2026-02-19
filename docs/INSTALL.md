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

### Quick install (recommended)

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
exec zsh
```

### Manual installation

```bash
# Clone the repository
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles

# Install chezmoi (verified release asset + checksum)
VERSION="2.47.1"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
esac
ASSET="chezmoi_${VERSION}_${OS}_${ARCH}.tar.gz"
BASE_URL="https://github.com/twpayne/chezmoi/releases/download/v${VERSION}"
curl -fsSLO "$BASE_URL/checksums.txt"
curl -fsSLO "$BASE_URL/$ASSET"
if command -v sha256sum >/dev/null 2>&1; then
  grep -E "[[:space:]]${ASSET}$" checksums.txt | sha256sum -c -
else
  grep -E "[[:space:]]${ASSET}$" checksums.txt | shasum -a 256 -c -
fi
tar -xzf "$ASSET" chezmoi
install -m 755 chezmoi "$HOME/.local/bin/chezmoi"

# Apply dotfiles
~/.local/bin/chezmoi init --apply sebastienrousseau/dotfiles

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
