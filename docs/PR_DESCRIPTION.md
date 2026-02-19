# Release notes — v0.2.485

## Overview

v0.2.485 consolidates the 2026 hardening work merged on `master`: CI stability fixes, compliance workflow reliability, devcontainer prebuild resilience, and documentation/version synchronization.

## Highlights

- **CI reliability**
  - Fixed failing GitHub Actions jobs across shell linting, unit/coverage enforcement, Docker checks, and devcontainer prebuild.
  - Corrected workflow edge cases for SSH signature verification and hadolint execution.

- **Security and compliance hardening**
  - Improved insecure-pattern detection and compliance guard behavior.
  - Preserved strict signed-commit enforcement while supporting SSH-signed commit verification context in CI.

- **Tooling and diagnostics**
  - Added MCP doctor diagnostics script and tests.
  - Updated chezmoi installer verification script to current upstream checksum asset naming.

- **Documentation and release alignment**
  - Synced README/docs tag/version references to `v0.2.485`.
  - Added `docs/BACKLOG_2026_HARDENING.md` to track prioritized follow-on upgrades.

## Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.485/install.sh)"
exec zsh
```

Non-interactive:

```bash
DOTFILES_NONINTERACTIVE=1 sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.485/install.sh)"
```

## Upgrade

```bash
dot update
```
