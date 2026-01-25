# Changelog

All notable changes to this project are documented here.

## v0.2.475

### Added

- **Shell Configuration**
  - Added `.profile` with POSIX-compatible login shell configuration
  - Added `.bashrc` fallback for non-Zsh environments
  - Added `.inputrc` with enhanced Readline configuration
  - Added `.vimrc` legacy support for environments without Neovim
  - Added `.Xresources` with X11 configuration and Catppuccin theme

- **Database CLI Configuration**
  - Added `.psqlrc` with enhanced PostgreSQL CLI configuration
  - Added `.sqliterc` with SQLite CLI settings
  - Added `mycli` configuration for MySQL CLI
  - Added `redis-cli` configuration
  - Added `mongosh` configuration for MongoDB Shell

- **Kubernetes Tooling**
  - Added `kubectx` and `kubens` aliases for context/namespace switching
  - Added `stern` aliases for multi-pod log tailing
  - Added `kube-linter` aliases for manifest linting
  - Added `kubesec` aliases for security scanning
  - Added `minikube` configuration and aliases
  - Enhanced Kubernetes aliases with comprehensive kubectl shortcuts

- **Nix Integration**
  - Added `packages` output to Nix flake
  - Added `dot-utils` meta-package derivation
  - Added `tmux`, `eza`, `yq`, `age`, `gnupg` to package list
  - Added install hook script for `nix profile install`

- **Dot CLI**
  - Added `dot --version` to display version information
  - Added `dot add` to add files to chezmoi source
  - Added `dot status` to show configuration drift
  - Added `dot cd` to print source directory path
  - Enhanced `dot tools` with `install` subcommand for Nix shell

- **Docker Tooling**
  - Added comprehensive Docker aliases (`dco`, `dprune`, `dlogsf`, `dexec`)
  - Added Docker Compose aliases (`dco` for `docker compose`)
  - Added Docker Buildx aliases for multi-platform builds
  - Added Lazydocker configuration (`config.yml`)
  - Added support for Dive and Hadolint

- **Tmux Enhancements**
  - Added vim-style copy bindings (`v` for selection, `y` for yank)
  - Added tmux-sessionizer script for fuzzy session switching
  - Updated clipboard integration for macOS and Linux

- **CI/CD**
  - Added Luacheck CI for Lua linting
  - Added shfmt format checking for shell scripts
  - Added Gitleaks secrets scanner
  - Added link rot checker for documentation
  - Added idempotency double-run test
  - Expanded test matrix to include macOS-13, macOS-14, and multiple Ubuntu versions

- **Completions**
  - Added Bash completion for the `dot` CLI
  - Enhanced Zsh completion with command descriptions

- **Documentation**
  - Enhanced installation guide with Nix instructions
  - Enhanced troubleshooting guide with more common issues
  - Added comprehensive tools list with tables
  - Added aliases reference documentation
  - Added feature flags documentation
  - Enhanced architecture documentation with diagrams
  - Enhanced CODEOWNERS with detailed ownership rules
  - Enhanced contributing guide with PR guidelines

### Changed

- Updated all version references to v0.2.475
- Made shebangs portable (`#!/usr/bin/env bash`)
- Improved documentation with Apple-style clarity
- Updated Brewfile.cli with Kubernetes tools

### Fixed

- Fixed duplicate alias conflicts in Docker aliases

## v0.2.474

- See the release notes and commit history for detailed changes.

## v0.2.472

- See the release notes and commit history for detailed changes.
