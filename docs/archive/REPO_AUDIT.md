# Repo Audit

## Source of truth
- `~/.dotfiles` (chezmoi source directory)

## Key directories
- `.chezmoitemplates/` - templated aliases, functions, paths
- `dot_config/` - configs mapped into `~/.config`
- `dot_local/` - binaries and local data (e.g., `dot` CLI)
- `scripts/` - diagnostics, tests, tooling
- `tests/` - sandbox Dockerfile
- `nix/` - optional Nix toolchain

## Notable dependencies
- `chezmoi`
- `zsh`, `starship`
- `neovim`
- `ripgrep`, `fd`, `bat`, `fzf`, `zoxide`
- `lazygit`

## Notes
- Repo-only files excluded via `.chezmoiignore`.
- Secrets are handled via `age` + `dot secrets` (see `docs/SECRETS.md`).
