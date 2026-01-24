# PR Title
feat(core): v0.2.472 release - shell UX fixes, provisioning hardening, and repo reorg

# PR Description

## Summary
This branch delivers the v0.2.472 release set with shell UX fixes, hardened Linux provisioning, and a repo reorganization that clarifies install/provision/scripts layout. It also addresses zsh completion handling, adds safe fzf/atuin installers, and tightens documentation links to the new structure.

## Key Changes (vs master)

### Shell & UX
- Updated zsh configuration to preserve full `fpath`, avoid duplicate entries, and include a managed fzf integration hook.
- Fixed alias wrapper to fall back when `bat` is unavailable; restored `l` alias when `eza` is installed.
- Refined modern tooling alias templates with safer bash/zsh handling.
- Tweaked tmux and Ghostty configs, plus refreshed shell README and Brewfile content.

### Provisioning & Installers
- Linux provisioning now handles existing `~/.fzf` installs safely and supports nested tarball layouts for GitHub releases (e.g., Atuin).
- Installer/provisioning helpers for Neovim install/upgrade and menu entry cleanup are now grouped under `install/helpers/`.
- Added/updated system tuning and policy files (sysctl tuning and Chrome managed policies).

### Neovim IDE
- Introduced a complete Neovim IDE configuration under `dot_config/nvim` (Lazy.nvim, plugins, LSP, UI, Rust/Python, Copilot, etc.).
- Updated dot-config plugin overlays and added a dedicated Neovim guide.

### Repo Organization
- Moved provisioning templates to `install/provision/` and reorganized `scripts/` into `core/`, `diagnostics/`, `tests/`, `ops/`, `security/`, and `tools/`.
- Relocated system policy files to `dot_etc/` (chezmoi-standard target for `/etc`).
- Moved legacy docs into `docs/legacy/`, and promoted the PR template to `.github/PULL_REQUEST_TEMPLATE.md`.
- Removed generated artifacts and duplicate `.config` samples from the repo root.

### CI/Docker/Docs
- Refreshed CI workflows and Docker test setup; added `scripts/tests/test-docker.sh`.
- Updated README and release docs to align with the new architecture and workflows.

## Notable New Files
- `dot_config/nvim/**` and `docs/neovim_ide_guide.md`
- `install/helpers/install_neovim.sh`, `install/helpers/upgrade_neovim_nightly.sh`, `install/helpers/hide_menu_entries.sh`
- `dot_etc/sysctl.d/99-tuning.conf`, `dot_etc/opt/chrome/policies/managed/*.json`
- `dot_local/share/zsh/completions/.keep`

## Testing
- Manual verification of `chezmoi apply` on Linux.
- `fzf` and `atuin` provisioning verified locally.
- `chezmoi apply --dry-run` verified after repo reorg.

## Notes
- This branch includes a broad set of release changes; please review by category (shell/provisioning/Neovim/docs) for easier validation.
