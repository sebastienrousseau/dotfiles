# PR Title
feat(core): v0.2.472 release - shell UX, provisioning fixes, and Neovim IDE

# PR Description

## Summary
This branch delivers the v0.2.472 release set, including a full Neovim IDE configuration, updated shell/alias layers, improved provisioning/installers, and documentation/CI refreshes. It also fixes zsh completion path handling and makes Linux provisioning resilient to existing installs (e.g., fzf and tarball layouts).

## Key Changes (vs master)

### Shell & UX
- Updated zsh configuration to preserve full `fpath`, add a managed fzf integration hook, and avoid alias recursion regressions.
- Refined modern tooling alias templates and generated alias output, with guardrails for bash/zsh execution paths.
- Tweaked tmux and Ghostty configs, plus refreshed shell README and Brewfile content.

### Provisioning & Installers
- Linux provisioning now handles existing `~/.fzf` installs safely and supports nested tarball layouts for GitHub releases (e.g., Atuin).
- Installer and provisioning logic tightened across scripts, plus new helper scripts for Neovim install/upgrade and menu entry cleanup.
- Added/updated system tuning and policy files (sysctl tuning and Chrome managed policies).

### Neovim IDE
- Introduced a complete Neovim IDE configuration under `.config/nvim` (Lazy.nvim, plugins, LSP, UI, Rust/Python, Copilot, etc.).
- Updated dot-config plugin overlays and added a dedicated Neovim guide.

### CI/Docker/Docs
- Refreshed CI workflows and Docker test setup; added `test-docker.sh`.
- Updated README and release docs to align with the new architecture and workflows.

## Notable New Files
- `.config/nvim/**` and `docs/neovim_ide_guide.md`
- `scripts/install_neovim.sh`, `scripts/upgrade_neovim_nightly.sh`, `scripts/hide_menu_entries.sh`
- `etc/sysctl.d/99-tuning.conf`, `etc/opt/chrome/policies/managed/*.json`
- `dot_local/share/zsh/completions/.keep`

## Testing
- Manual verification of `chezmoi apply` on Linux.
- `fzf` and `atuin` provisioning verified locally.

## Notes
- This branch includes a broad set of release changes; please review by category (shell/provisioning/Neovim/docs) for easier validation.
