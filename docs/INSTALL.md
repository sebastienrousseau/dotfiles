# Get started

This guide describes the supported platforms, prerequisites, and the standard install path.

## Supported platforms

- macOS (Homebrew)
- Ubuntu/Debian (apt)
- WSL2 (Ubuntu/Debian)

## Prerequisites

Required:
- `git`
- `curl`

Optional (feature‑dependent):
- Homebrew (macOS)
- `apt-get` (Linux)
- Docker or Podman (sandbox)
- Nix (optional toolchain)
- gum (required for `dot learn`)

## Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.475/install.sh)"
exec zsh
```

## What happens

- The installer downloads a pinned Chezmoi bootstrap and applies this repo.
- Chezmoi hooks install OS packages, fonts, and optional apps.
- The `dot` CLI becomes available in `~/.local/bin`.

## Optional: gum

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

## Troubleshooting

If install hooks fail, check `~/.local/share/dotfiles.log` and review `docs/TROUBLESHOOTING.md`.
