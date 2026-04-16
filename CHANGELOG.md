# Changelog

This file documents all notable changes to this project.

## v0.2.500

### Added
- **Wallpaper-driven theme engine** — themes are no longer hand-crafted. `extract-theme.py` uses K-Means clustering in CIELAB color space to extract dominant colors from any wallpaper image and generate a full terminal palette (16 ANSI colors, accent, bg/fg, panel, border) with WCAG AAA contrast enforcement.
- **Automatic wallpaper discovery** — `rebuild-themes.sh` scans system wallpapers (macOS `/System/Library/Desktop Pictures/`, Linux `/usr/share/backgrounds/`) and custom wallpapers (`~/Pictures/Wallpapers/`). Custom overrides system. Themes are cached and only regenerated when wallpapers change.
- **`dot theme rebuild`** — new command to regenerate themes from discovered wallpapers. Supports `--force` (ignore cache) and `--list` (show wallpapers without rebuilding). Parallel processing (4 jobs).
- **System wallpaper fallback** — when no custom wallpaper exists, `wallpaper-sync.sh` maps theme names to platform-native wallpapers before falling back to "skip gracefully".
- **HEIC → PNG auto-conversion** on Linux via `magick`/`heif-convert`/`convert`.
- **macOS accent from wallpaper** — `macos_accent` field in generated themes maps wallpaper dominant hue to macOS accent color. `dot-theme-sync` reads it from themes.toml instead of a hardcoded case statement.
- **Build artifact redirection** — Cargo, Go, pip, uv, Zig caches → `/tmp/builds/`.

### Changed
- **themes.toml is now auto-generated** — run `dot theme rebuild` after adding wallpapers. Do not edit manually.
- **Theme family derived from themes.toml** — `get_theme_family()` in `switch.sh` reads the `family` field dynamically instead of hardcoded case patterns.
- **macOS appearance refresh** — kills cfprefsd/SystemUIServer/Dock/System Settings after accent changes.
- **Graceful wallpaper fallback** — theme switching works without custom wallpapers. Core changes (colors, accent, dark/light) always apply; wallpaper is optional.

### Removed
- **Static theme definitions** — all hand-crafted theme entries replaced by wallpaper-driven generation.

## v0.2.497

### Added
- **Verified chezmoi installer** — `install.sh` prefers `scripts/ci/install-chezmoi-verified.sh` with SHA256 checksum validation before falling back to `get.chezmoi.io`.
- **detect-secrets baseline** — `.secrets.baseline` for pre-commit secret scanning alongside gitleaks.
- **Lua plugin module headers** — `@module` docstrings for ui.lua, coding.lua, lsp.lua, editor.lua, dap.lua explaining plugin selection rationale.

### Changed
- **CI hardening** — Pinned `nix-installer` to SHA, removed `continue-on-error` from Home Manager build, replaced `mapfile` with portable `while read` loops.
- **Plugin version pins** — toggleterm pinned to `^2`, venv-selector uses `version = false` instead of `branch = "main"`.
- **DAP port configurable** — `DAP_DEV_SERVER_PORT` environment variable overrides default port 3000.
- **SSH template hardening** — Added `hasKey` guard for `.chezmoi.kernel` in SSH config template.
- **Test framework** — Restored `TESTS_PASSED`/`TESTS_FAILED` counter names for backward compatibility with 383 test files; fixed `mock_os` PATH restoration between test cases.
- **Documentation** — Fixed default shell reference (Zsh → Fish) in INSTALL.md, added CI badge and test runner to README, added function docstrings to `utils.sh`.

### Fixed
- **Shell compatibility** — Replaced zsh-only `unfunction` with POSIX `unset -f` in shell templates.
- **Quote nesting** — Fixed broken double-quote nesting in `run_onchange_after_fonts.sh.tmpl`.
- **Quoted expansion** — Added missing quotes around `$ZINIT_HOME` in zinit bootstrap.
- **JSON injection** — Escaped double quotes in `health.sh` JSON output fields.
- **Arithmetic portability** — Replaced `$(seq ...)` with `((i=N; i>=1; i--))` in `log-rotate.sh`.

## v0.2.496

### Added
- **Startup budget tracking** — CI now captures per-component timing from `DOTFILES_DEBUG=1` and fails on regression.
- **Behavioral unit tests** — 10 critical functions now have runtime behavior tests (extract, genpass, encode64, path_prepend, platform detection, lazy loaders).
- **Property-based tests** — `property_testing.sh` framework wired up with roundtrip, idempotence, and length-invariant tests.
- **git-cliff configuration** — Automated CHANGELOG generation from conventional commits.
- **Nix CI gate** — Home Manager activation package built and validated in CI.

### Changed
- **Performance** — Lazy-loaded `thefuck` (~200ms saving) and cached `carapace` output via `_cached_eval` (~50ms saving).
- **Starship timeout** — Reduced `command_timeout` from 2000ms to 500ms for snappier prompts in large repos.
- **PATH consolidation** — All PATH mutations now originate from `00-core-paths.sh.tmpl`; removed scattered prepends from zshenv/zprofile stubs.
- **heal.sh modular split** — Broken into domain modules (heal-shell, heal-tools, heal-perms, heal-cache) for testability.
- **dot CLI modular split** — Subcommands dispatched to individual scripts in `scripts/dot/commands/` for maintainability.

### Fixed
- **Security** — Replaced `curl|sh` pipes in `heal.sh` (starship, atuin) with download-to-temp + shebang validation. Pinned all heal.sh GitHub release versions with SHA256 checksums.
- **Security** — `install.sh` now uses the secure `install/lib/chezmoi.sh` library instead of inline `curl|sh`.
- **Security** — `dot-bootstrap` Nix installer now downloads to temp file with validation before execution.
- **Security** — Extended `insecure-tls-check` pre-commit hook to cover `.tmpl` files.
- **Security** — Added `sudo` availability guard in `heal.sh` before package manager calls.
- **Documentation** — Fixed placeholder URLs in WSL2 troubleshooting guide.
- **Documentation** — Added ADR-007 and ADR-008 to ADR index.
- **Documentation** — Linked hero-shot.svg from README; updated hero-shot to show factual `dot doctor` output.
- **Reliability** — `bench.sh` now uses `mktemp` instead of hardcoded `/tmp/bench.json`.

## v0.2.495

### Fixed
- **Installation failure (Issue #807)**: Resolved "unbound variable" errors in `install.sh` by correctly initializing color and path variables.
- **Shell Compatibility**: Fixed syntax errors when running `install.sh` with `sh` by ensuring the script runs with `bash` and updating documentation accordingly.
- **Broken Links**: Updated installation instructions in `README.md` and `docs/guides/INSTALL.md` to use the GitHub raw URL, bypassing issues with the `dotfiles.io` redirect.
- **Documentation Sync**: Synchronized versioning and installation commands across all documentation and source files.

### Changed
- **Repository Restructuring**: Reorganized non-deployed files for improved discoverability.
  - Docs categorized into `architecture/`, `guides/`, `reference/`, `security/`, `operations/` subdirectories.
  - Tests promoted to top-level `tests/` with domain-based unit test subdirectories.
  - Function templates grouped into subdirectories matching `groups.json` groups.
  - `install/helpers/` merged into `install/lib/`.
  - Renamed `.chezmoitemplates/gnome/` to `.chezmoitemplates/desktop/`.
  - Added `docs/NAMING_CONVENTIONS.md` standardization guide.
  - Added `dot_config/.module-manifest.json` for logical grouping of flat config directories.

## v0.2.493

### Added
- Implementation of `_cached_eval` for Zsh, Bash, and Fish for ultra-fast startup.
- Full integration of `zoxide` and `atuin` in Nushell with caching.
- Explicit management of `sgpt`, `poetry`, `fisher`, `micro`, and `pueue` configs.
- Robust `target_os` detection for Arch/CachyOS in `install.sh`.

### Changed
- Refactored `install.sh` to use a modular `main()` function.
- Moved XDG exports in `dot_bashrc` above interactive checks.
- Optimized Zellij configuration with 2026-ready UX (rounded corners, compact layout).

### Fixed
- Resolved 100% of security alerts regarding `apt-get` recommendations.
- Achieved 100.00% module test coverage with new maintenance tests.
- Fixed Nix profile sourcing drift in `dot_zshenv`.
- Resolved CI failures across linting, formatting, and unit test suites.



### Added

- **2026 Frontier Stack** — Full support for Fish (Autoloading) and Nushell (Structured Data).
- **Deterministic Portability** — Nix Flakes integration for bit-for-bit identical environments.
- **Async Task Management** — Integrated Pueue daemon for non-blocking background operations.
- **Local AI RAG** — `dot-ai` semantic search over your dotfiles configuration.
- **Wasm Runtime** — Wasmtime support for ultra-fast, pre-compiled Rust/Zig tools.
- **One-Command Provisioner** — `dot-bootstrap` for instant environment setup on clean servers.
- **OS Theme Sync** — `dot theme sync` to match OS appearance (macOS/GNOME).
- **Yazi Synergy** — `yy` wrapper for "cd-on-exit" directory navigation.

### Changed

- **Fish Shell** — Transitioned from monolithic aliases to a dynamic function autoloading pipeline.
- **Starship** — Added async indicators for background tasks and Nix environments.
- **Diagnostics** — `dot doctor` and `dot heal` are now mise-aware and 2026-stack compatible.
- **Neovim** — Migrated IDE toolchain (LSPs/Linters) into the Nix Flake.

## v0.2.491

### Added

- **Fast mode** — `DOTFILES_FAST=1` skips heavy startup work for the quickest first prompt.
- **Runtime toggles** — `DOTFILES_DEFER_ZINIT` and `DOTFILES_ENABLE_COLORS` controls.
- **Ultra-fast mode** — `DOTFILES_ULTRA_FAST=1` runs a minimal init path.
- **Minimal prompt** — `DOTFILES_ULTRA_FAST_PROMPT=1` keeps the ultra-fast prompt lightweight.
- **AI opt-in** — `DOTFILES_AI=1` enables AI helper scripts.

### Changed

- **Deferred tool init** — Atuin, Starship, Zoxide, and FZF now load after the first prompt.
- **Zinit bootstrap** — Deferred by default to reduce first-prompt latency.
- Updated all version references to v0.2.491.

### Documentation

- Added performance mode guidance and updated benchmark wording to reflect real-world variance.

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
