# Changelog

This file documents all notable changes to this project.

## v0.2.480

### Added

- **Catppuccin theme support** — Added all four Catppuccin flavours (latte, frappe, macchiato, mocha) with comprehensive theming across VS Code, Neovim, GTK 3/4, GNOME Shell, and Nix home-manager integration.
- **AI pair programming** — Added `aider-chat` CLI tool for AI-powered code editing and pair programming sessions.
- **Enhanced Python AI tools** — Added `shell-gpt` and `posting` to Python tools provisioning for improved CLI AI assistance.
- **Git workflow improvements** — Added `git-absorb` for automatic fixup commits and intelligent commit history management.
- **Template helper functions** — Added comprehensive chezmoi template helpers for feature flags, git variables, OS detection, and path utilities.

### Changed

- **Syntax highlighting performance** — Switched from `zsh-syntax-highlighting` to `fast-syntax-highlighting` for improved shell responsiveness.
- **Technical debt reduction** — Achieved 10/10 technical debt score through modular installer refactoring with dedicated libraries for backup, chezmoi, OS detection, and package management.
- **Documentation architecture** — Comprehensive documentation overhaul with centralized docs/README.md, helper function documentation, and improved template organization.
- **Theme switching enhancement** — Enhanced `switch.sh` with family toggling between Tokyo Night and Catppuccin theme families.

### Fixed

- **Template processing** — Fixed undefined `$name` variable in README.md template that was causing `chezmoi apply` failures.
- **Code quality** — Resolved all remaining Codacy static analysis warnings for improved code maintainability.
- **CI optimization** — Optimized GitHub Actions workflows to reduce usage and cost.

### Documentation

- **ADR documentation** — Added comprehensive Architecture Decision Records (ADR-005 for chezmoi choice, ADR-006 for shell selection).
- **Template validation** — Added comprehensive unit tests for template validation and processing.
- **Theme documentation** — Added documentation for Catppuccin installation, GNOME theme application, and cross-platform theme switching.

## v0.2.479

### Added

- **Cross-platform Brewfile** — Unified Brewfile with OS.mac?/OS.linux? platform detection for seamless package management across macOS, Linux, and WSL.
- **Enhanced WSL detection** — Added DOTFILES_OS variable in zprofile for improved Windows Subsystem for Linux compatibility.
- **AI shell tooling** — Added generic ollama aliases (ol, olr, oll, olp, ollama-status, ollama-show) for cross-platform AI model interaction.
- **Homebrew optimization** — Added performance settings disabling analytics and auto-update for faster package operations.
- **Language-specific PATH setup** — Enhanced PATH configuration for Go, Rust, .NET, and Python development environments.

### Changed

- **Platform-agnostic aliases** — Removed personal model-specific ollama functions, keeping only generic cross-platform aliases that work on any Ollama installation.
- **Brewfile organization** — Reorganized Brewfile sections for clarity and removed platform-specific packages from cross-platform sections.
- **Feature flags documentation** — Expanded FEATURES.md with comprehensive feature flag table, template processing examples, and troubleshooting guide.

### Fixed

- **Test framework reliability** — Resolved shellcheck warnings and mock export issues in unit test framework.
- **CI compatibility** — Fixed alias tests to use proper `alias` command instead of `type`, enabled `shopt -s expand_aliases` in test subshells.
- **PATH isolation** — Fixed unavailable command tests by using isolated PATH to ensure system commands aren't found during testing.

### Documentation

- **AI aliases documentation** — Updated documentation for ollama aliases and cross-platform AI tooling.
- **Architecture notes** — Enhanced feature flag documentation with template processing explanation and runtime access patterns.

## v0.2.478

### Added

- **Lazy alias loading** — Tool-specific aliases (~137KB across 35+ categories) now load after the first prompt via a `precmd` hook, keeping shell startup fast while retaining full alias coverage.
- **GPG signature verification** in `install.sh` — Verifies chezmoi release checksums against the upstream GPG signature with graceful degradation when `gpg` is unavailable.
- **Unit tests for all refactored scripts** — 100 new tests across 7 test files covering alias split, lazy hooks, FNM fix, PATH entries, GPG verification, CI pinning, gitleaks config, heal.sh fixes, and `dot new` Python guard.

### Changed

- **Alias split architecture** — Separated monolithic alias template into eager (`90-ux-aliases.sh`, 14 core categories) and lazy (`91-ux-aliases-lazy.sh`, 35+ tool categories).
- **FNM triple initialization fixed** — Removed eager `eval "$(fnm env)"` from `.zshrc` and duplicate lazy-load block from `30-options.zsh`; single lazy-load via wrapper functions remains.
- **CI chezmoi version pinned** to v2.47.1 with correct `-t` tag flag (was `-v`, which is invalid for `get.chezmoi.io`).
- **`dot_zshenv` PATH entries** — Added idempotent `~/.local/bin` and `/opt/homebrew/bin` PATH guards so tools are available before `.zshrc` loads.
- **`dot new` Python guard** — Moved Python pre-flight check before filesystem operations to avoid creating empty directories on failure.
- Updated all version references to v0.2.478.

### Fixed

- **`heal.sh` SC2015** — Replaced `A && B || C` pattern with proper `if/then` to satisfy shellcheck.
- **`heal.sh` shfmt formatting** — Fixed case branch spacing and pipe operator alignment.
- **Gitleaks false positive** — Allowlisted chezmoi GPG public key fingerprint via inline annotation and commit SHA.

### Documentation

- Added shell startup flow (16 phases) to `ARCHITECTURE.md` with rc.d and shell/ load order tables.
- Added alias system documentation covering eager/lazy split, glob ordering, and manifest convention.
- Added startup flow diagram to `README.md`.

## v0.2.477

### Added

- **Topgrade provisioning parity** across macOS, Linux, and WSL
  - Added `topgrade`, `mise`, `rustup`, `tmux`, `pipx`, `ruby`, `yazi` to Brewfile.cli
  - Added Linux binary installs for topgrade, mise, yazi with SHA256 verification
  - Added rustup via official installer with `--no-modify-path`
  - Added `cargo-install-update` for topgrade's cargo step
  - Added `gh` (GitHub CLI) to Linux package managers
  - Added `tmux`, `pipx`, `ruby` to Linux system packages
  - Created `run_onchange_12-tmux-plugins.sh.tmpl` for tpm provisioning
  - Added chezmoi-managed `topgrade.toml.tmpl` with platform-specific disable lists
  - Moved stylua and delta installs after rustup so cargo is available
  - Replaced yazi hint-only block with actual binary download

- **Security and GPG**
  - Added `gnupg` to Brewfile.cli and Linux package lists (#381)
  - Updated GPG agent cache TTL to 1 day (86400 seconds) (#392)

- **Node.js tooling**
  - Added `.npmrc` config with scoped registries support (#439)
  - Added `.yarnrc.yml` for Yarn Berry configuration (#440)
  - Added `.noderc` for Node REPL configuration (#271)
  - Added `eslint_d` global install for fast linting (#441, #267)
  - Added `prettier_d` global install for fast formatting (#442, #268)
  - Added `typescript` and `typescript-language-server` global installs

- **Bun**
  - Added `bunfig.toml` configuration (#447, #273)
  - Added Bun paths to core-paths

- **Kubernetes**
  - Added KUBECONFIG merge logic for `~/.kube/config.d/*` (#487, #313)
  - Added `hm` alias for `helm` (#489, #315)
  - Added K9s configuration with Catppuccin Mocha skin (#314)
  - Added `kube-linter` to Brewfile.cli (#319)
  - Added `kubesec` to Brewfile.cli (#318)

- **Neovim**
  - Added `ts_ls` (TypeScript) to mason-lspconfig ensure_installed (#269)
  - Added DAP configuration with `js-debug-adapter` support (#270)

- **macOS**
  - Added Finder List View as default view mode (#511)
  - Added Finder path bar, status bar, and folders-first sorting

- **Dot CLI**
  - Added `dot packages` command to list installed packages (#375)

- **Testing**
  - Added 14 security validation tests in `test_security_fixes.sh`
  - Added unit tests for TOCTOU prevention, input validation, and safe parsing

### Changed

- Updated all version references to v0.2.477
- **CI/CD consolidation**
  - Consolidated 5 workflow files into 3 (`ci.yml`, `codeql.yml`, `security-release.yml`)
  - Implemented 5-stage pipeline: LINT → SECURITY → TEST → QUALITY → BENCHMARK
  - Added consistent naming convention: `Category / Specifics`
  - Added concurrency groups for faster PR feedback
  - Merged Docker tests and benchmarks into main CI workflow

### Fixed

- **Security hardening (OWASP)**
  - `mount_read_only.sh`: Input validation and secure temp file with `mktemp`
  - `chezmoi-apply.sh`/`chezmoi-update.sh`: Safe flag parsing with `read -ra`
  - `tmux-sessionizer`: Session name sanitization to prevent injection
  - `install.sh`: Escaped sed metacharacters for safe pattern matching
  - `teleport.sh`: Added tar safety flags (`--no-absolute-names`)
  - `permission.aliases.sh`: Added warnings for overly permissive modes (666/777)
  - `genpass.sh`: Numeric input validation
  - `backup.sh`: Enhanced error handling for tar operations
  - `age-init.sh`: Safe JSON output with `json.dumps`

- **Cross-platform compatibility**
  - `99-custom.paths.sh`: Added macOS guards and path existence checks
  - `00-default.paths.sh`: Added darwin guard for Homebrew, Linuxbrew support
  - `view-source.sh`: Plain curl command for portability
  - `configuration.aliases.sh`: File existence checks before sourcing
  - `install_neovim.sh`: Linux-only guard, user-local fallback when no sudo
  - `upgrade_neovim_nightly.sh`: Platform guard, sudo fallback
  - `run_before_00-audit.sh`: Container-safe hostname detection
  - Removed hardcoded `/usr/bin` paths in `last.sh`, `hexdump.sh`, `httpdebug.sh`, `caffeine.sh`

## v0.2.476

### Added

- **AI CLI Tools (NPM-based)**
  - Added `claude` (@anthropic-ai/claude-code) - Anthropic Claude CLI for AI-powered coding
  - Added `gemini` (@google/gemini-cli) - Google Gemini CLI for terminal AI assistance
  - Added `codex` (@openai/codex) - OpenAI Codex CLI for code generation and understanding
  - Added `opencode` (opencode-ai) - OpenCode AI assistant with TUI
  - Added `droid` (@factory/cli) - Factory AI Droid for intelligent code orchestration
  - All tools installed globally via npm/fnm
  - Auto-install fnm and Node.js LTS if not present

### Changed

- Updated all version references to v0.2.476

## v0.2.474


### Added

- **Shell configuration**
  - Added `.profile` with POSIX-compatible login shell configuration
  - Added `.bashrc` fallback for non-Zsh environments
  - Added `.inputrc` with enhanced Readline configuration
  - Added `.vimrc` legacy support for environments without Neovim
  - Added `.Xresources` with X11 configuration and Catppuccin theme

- **Database CLI configuration**
  - Added `.psqlrc` with enhanced PostgreSQL CLI configuration
  - Added `.sqliterc` with SQLite CLI settings
  - Added `mycli` configuration for MySQL CLI
  - Added `redis-cli` configuration
  - Added `mongosh` configuration for MongoDB Shell

- **Kubernetes tooling**
  - Added `kubectx` and `kubens` aliases for context/namespace switching
  - Added `stern` aliases for multi-pod log tailing
  - Added `kube-linter` aliases for manifest linting
  - Added `kubesec` aliases for security scanning
  - Added `minikube` configuration and aliases
  - Enhanced Kubernetes aliases with comprehensive kubectl shortcuts

- **Nix integration**
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

- **Docker tooling**
  - Added comprehensive Docker aliases (`dco`, `dprune`, `dlogsf`, `dexec`)
  - Added Docker Compose aliases (`dco` for `docker compose`)
  - Added Docker Buildx aliases for multi-platform builds
  - Added Lazydocker configuration (`config.yml`)
  - Added support for Dive and Hadolint

- **Tmux enhancements**
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

- Updated all version references to v0.2.474
- Made shebangs portable (`#!/usr/bin/env bash`)
- Improved documentation with Apple-style clarity
- Updated Brewfile.cli with Kubernetes tools

### Fixed

- Fixed duplicate alias conflicts in Docker aliases

## v0.2.474

- See the release notes and commit history for detailed changes.

## v0.2.472

- See the release notes and commit history for detailed changes.
