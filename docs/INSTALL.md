# Installation

This guide describes the supported platforms, prerequisites, and the standard install path.

## Supported Platforms

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

## Quick Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.474/install.sh)"
exec zsh
```

## What happens during install

- The installer downloads a pinned Chezmoi bootstrap and applies this repo.
- Chezmoi hooks install OS packages, fonts, and optional apps.
- The `dot` CLI becomes available in `~/.local/bin`.

## Updating

```bash
dot update
```

## Troubleshooting

If install hooks fail, check `~/.local/share/dotfiles.log` and review `docs/TROUBLESHOOTING.md`.
