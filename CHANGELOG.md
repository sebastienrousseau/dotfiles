# Changelog

This file documents all notable changes to this project.

## v0.2.501

### Added

- **Warp + iTerm2 theme support** — the two terminals the theme system did not yet cover are now first-class. `dot_warp/themes/dotfiles.yaml.tmpl` deploys a Warp theme; `run_onchange_22-iterm2-profile.sh.tmpl` writes an iTerm2 Dynamic Profile to `~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json`. Both pick up the active theme's `.term` palette, so one `chezmoi apply` switches all six supported terminals (kitty, alacritty, wezterm, foot, warp, iterm2). The README's "Why this repo is different" surface lists this under wallpaper-driven themes.
- **Starship Transient Prompt (fish)** — `dot_config/fish/conf.d/init.fish.tmpl` calls `enable_transience` after the cached `starship init`, collapsing past prompts to the `[character]` glyph in scrollback. The zsh implementation is a forward-compatibility hook only — Starship 1.24.2 does not yet ship `enable_transience` for zsh (upstream tracker [starship/starship#3522](https://github.com/starship/starship/issues/3522)). Rationale and rejected alternatives recorded in [ADR-010](docs/adr/ADR-010-starship-transient-prompt.md).
- **`_cached_eval` enhancements (#847)** — `EVALCACHE_DISABLE=true` bypass for debugging, realpath sidecar pin to catch PATH-shadow swaps, file-path argument mtime check, init-failure handling (warns and returns rc instead of caching an empty output), and a new `_cached_eval_clear` helper. Applied to all three implementations (zsh, bash, fish). Adds shdoc docstrings.
- **JSON Schema for `.chezmoidata.toml`** — `config/chezmoidata.schema.json` (draft-07) plus `.taplo.toml` and a new `lint-chezmoidata` CI job. Catches typos in feature flags, profile names, `default_shell`, and `node_manager` at PR time.
- **OIDC trusted publishing for npm (#836)** — `publish-npm` workflow authenticates via OIDC instead of a long-lived `NPM_TOKEN`. Provenance is attached to every published tarball. The migration is breaking on the CI side: `NPM_TOKEN` is no longer used. **Manual followup needed before the first OIDC release**: configure Trusted Publishing on npmjs.com for `@sebastienrousseau/dotfiles` pointing at `sebastienrousseau/dotfiles` + `.github/workflows/npm-publish.yml`.
- **`lint-copyright` in `ci.yml` (#834)** — the fast CI pipeline now runs the reusable copyright-header lint. Previously only `ci-enforced.yml` ran it.
- **Test coverage roadmap, Slices 1 + 2 (#883)** — replaced the broken kcov pipeline with a pure bash xtrace runner that works on Linux and macOS. Slice 1 established a 2.72% measured baseline; Slice 2 converted 59 shallow tests into deep-execution tests via a new `tests/framework/coverage_helpers.sh` (sandbox + safe-mode entry-point exercise) and landed coverage at 10.80% on CI / 12.01% locally. `MIN_COVERAGE_PCT` floor raised 0 → 10.
- **GitHub Pages deploy of `docs/` to doc.dotfiles.io** — new `.github/workflows/pages.yml` builds the Jekyll site (cayman theme, kramdown, Liquid disabled for chezmoi-template snippets) and publishes on every push to master that touches `docs/**`. Replaces the old approach where `manual-publish.yml` deployed the multi-format manual to Pages.
- **PR consolidation — 8 Dependabot bumps (#839–#846)** — major bumps: `actions/deploy-pages` 4→5, `softprops/action-gh-release` 2→3, `actions/download-artifact` 4→8.0.1, `docker/setup-buildx-action` 3→4, `actions/upload-pages-artifact` 3→5, `actions/github-script` 8→9. Minor and SHA-only refreshes for `actions/cache`, `actions/setup-node`, `bridgecrewio/checkov-action`, `devcontainers/ci`, `docker/login-action`, the `github/codeql-action` family, and `trufflesecurity/trufflehog`. All actions remain pinned by full commit SHA.
- **Re-source guards** on the five shared library files where re-sourcing would corrupt state: `tests/framework/{assertions,mocks}.sh` and `scripts/dot/lib/{utils,ui,log}.sh`.
- **`tests/unit/ci/test_validate_chezmoidata.sh`** — 13 assertions covering the new schema-validator script. Restores the 100% module-coverage floor that the schema commit had broken.
- **`tests/unit/ci/test_check_*.sh`** — four new module-coverage tests for `check-insecure-tls`, `check-dangerous-chmod`, `check-regression-traceability`, and `run-coverage`. Keeps module coverage at 221/221.
- **`docs/operations/COVERAGE.md`** — documents the why-not-kcov decision (Ubuntu 24.04 bash 5.2 incompatibility) and the xtrace approach (`PS4 + BASH_ENV`).
- **`.chezmoiignore`** — new file at the repo root. Excludes 880 → 408 paths from chezmoi's managed surface: build artifacts (`coverage/`, `nightly-reports/`, `_build/`), repo metadata (`README.md`, `CHANGELOG.md`, `LICENSE`, `.github/`, `.git/`), documentation tree (`docs/`, intended for doc.dotfiles.io, not `$HOME`), and CI scaffolding (`scripts/`, `tests/`, `examples/`, `install/`, `nix/`, `config/`, `.well-known/`). Also gates `dot_warp/` to macOS via a template conditional. Before this file, any developer machine that had run the test suite locally would have ~600 MB of coverage trace data deployed under `~/coverage/` on the next `chezmoi apply`.
- **Goose and Codex CLI in `dot ai`** — both AI agents now appear in the status surface under "Agents (autonomous)". `goose` and `codex` are wired in `_ai_mise_pkg` (so `dot ai-setup` knows their install targets), in the bridge `case` (so `dot goose --pattern X "prompt"` and `dot codex --pattern X "prompt"` route correctly), and in the route table in `dot_local/bin/executable_dot`.
- **Spinner feedback on slow operations** — `dot ai` now shows `Probing N AI tools (cached for 300s)…` during the cold-cache refresh. Previously the command sat silent for 15–30s on the first run after the 5-min TTL expired.

### Changed

- **README rewrite for accuracy and readability** — three concrete inaccuracies fixed: PowerShell was incorrectly listed as Tier-3 (ADR-007 does not place it in the tier system), `dot bundle --manual` was a flag that does not exist (correct command is `dot manual --offline`), and the supported-terminal list missed Warp and iTerm2. Six coverage gaps filled (Starship Transient, JSON Schema, OIDC, `_cached_eval` enhancements, Bash as explicit Tier-1, and several previously-unmentioned `dot` subcommands). Command count corrected from "30+" to "over 80". Flesch baseline 28.3 → 42.9 raw / 47.7 prose-only.
- **Header badges unified to `for-the-badge` style** — OpenSSF Scorecard and Codespaces badges now use shields.io renderings at the same height as Build / Version / Downloads.
- **`manual-publish.yml`** — Pages-deploy steps removed. The workflow now only builds the multi-format manual and attaches it to releases.
- **Coverage runner is now Linux + macOS** — the kcov-only runner had a hard Darwin skip. The xtrace runner works on both, so the pre-commit hook can invoke it on developer machines regardless of platform.
- **`MIN_COVERAGE_PCT` in `.github/workflows/coverage.yml`** — raised from aspirational `50` (which never measured anything) to a real `10` floor based on the Slice 2 baseline. Ratchets up with each subsequent slice.
- **`dot ai` runs probes in parallel** — the 14-tool cold-cache refresh now runs via `xargs -P` (defaults to `$(nproc)` workers, override via `DOTFILES_AI_PROBE_JOBS`). Cold-cache wall-time on a fast laptop: 6.2s → 1.9s. Warm-cache (within the 5-min TTL): ~0.07s, unchanged.

### Fixed

- **`core.hooksPath` config gap** — the global `commit-msg` hook is now tracked under chezmoi and pointed at by the user's git config, so the AI-attribution trailer fires on every commit.
- **Liquid templating false-mangle of chezmoi snippets in docs** — 14 files containing `{{ … }}` Go-template syntax inside code blocks were being silently evaluated as Liquid by Jekyll. Bulk-wrapped with `{% raw %}` / `{% endraw %}`.
- **Multiple `A && B || C` antipatterns** — restructured to proper `if/then/else` blocks across `tests/fuzz/fuzz_install.sh`, `tests/snapshots/test_snapshots.sh`, three diagnostics tests, two security tests, and `tests/unit/security/test_pre_push_bypass.sh`.
- **macOS reliability gate** — the `cov_exercise_script` helper now probes for `timeout` then `gtimeout` (coreutils on macOS) before falling back to no-timeout. The previous version returned `rc=127` for every script on macOS-latest.
- **Windows chezmoi installer fallback** — `setup-chezmoi` composite action now uses the upstream installer's `-t v$version` flag on Windows (Git Bash). The previous positional-arg form made chezmoi try to run itself as a subcommand and exit non-zero.
- **Typos hook allowlist** — added 9 entries for alias names (`yout`, `hom`, `cod`, `dsk`, `dwn`, `mus`, `pic`, `wth`) and SLSA terminology (`intoto`, `writeable`) that the hook incorrectly flagged.
- **`scripts/ci/check-insecure-tls.sh` and `compliance-guard.yml`** — both now exclude themselves and the `tests/` tree from the curl/wget/chmod pattern scans. The scanners were flagging their own legitimate pattern fixtures.
- **`dot health --fix` chezmoi-sync detection** — `chezmoi status` output has two columns: column 1 (last-applied vs. actual) and column 2 (actual vs. target). The health dashboard previously counted both columns, so a single uncommitted edit to a source file (column-1-only drift, normal during development) was reported as "1 file out of sync" even though `chezmoi apply` had nothing to fix. The dashboard now counts only column-2 drift (the apply-actionable kind) and surfaces source-only drift as an informational footnote.
- **`dot health --fix` post-apply verification** — `heal_chezmoi_drift` previously ran `chezmoi apply --force` via `_pkg_install`, which silenced stdout/stderr. When apply partially failed (e.g., on conflicting files), the next health-check pass showed the same drift count and the user had no signal that anything was wrong. The heal now captures the apply log, re-runs `chezmoi status` to verify the drift cleared, and reports either "✓ X file(s) synced" or "⚠ X applied, Y still drifted — run `chezmoi diff` to inspect". On hard failure, the last 5 lines of the apply log are surfaced inline.
- **`ui_spinner_stop` rc=1 on a TTY** — the function's last line was `[[ ! -t 1 ]] && printf "\n"`, which evaluates to rc=1 when stdout is a TTY. Under `set -euo pipefail`, that rc killed every caller, including `_ai_refresh_status_cache` — silently leaving the user with an empty cache file. Added explicit `return 0`.
- **macOS `xargs -I{} -n1` payload splitting** — `_ai_refresh_status_cache` originally passed `-n1` on top of `-I{}`, which on BSD-xargs triggers a quirk where the input line is word-split on whitespace. Entries like `"0|Agents (autonomous)|…"` arrived as `["0|Agents", "(autonomous)|…", …]`, garbling every probe. Removed the `-n1` (it's redundant with `-I{}`).
- **macOS `xargs` apostrophe-quote bug** — BSD-xargs reads `Block's coding agent` as an unterminated single quote, aborts parsing, and drops every record after the offending one. Switched the probe pipeline to null-delimited input (`printf '%s\0' …` + `xargs -0`). This was masking Goose's presence: it had been silently absent from `dot ai` even when installed.
- **AI dispatcher route gaps** — four bridge tools (`autohand`, `vibe`, `qwen`, `zai`) were accepted by the bridge `case` in `ai.sh` but missing from the route table in `dot_local/bin/executable_dot`. `dot autohand …` was hitting "Unknown ai command". Routes filled in.
- **`run_ai_with_context` missing handlers for Goose and Codex** — `dot codex "prompt"` and `dot goose "prompt"` would route correctly through the dispatcher and bridge case but then fall through to "Unsupported tool" because the per-tool execution case was missing. Added `codex)` and `goose)` arms.

### Security

- **OIDC trusted publishing for npm** — see Added above. Drops the long-lived `NPM_TOKEN` from CI.
- **SHA-pinned GitHub Actions everywhere** — confirmed across all workflows after the Dependabot consolidation.
- **`bash-dbgsym` not required** — the kcov-based coverage runner needed Ubuntu's debug symbols for bash, which created a supply-chain question (additional apt source). The xtrace replacement removes that requirement.

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
