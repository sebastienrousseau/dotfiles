# Release notes — v0.2.480

## Release overview

This release transforms the dotfiles into a high-performance, cross-platform system managed by **chezmoi**.

### Architecture
v0.2.480 is a portable **shell distribution** managed by `chezmoi` (source of truth in `~/.dotfiles`).

- **XDG-first**: Configs strictly mapped to `~/.config/` (no `~/.foo` sprawl).
- **Single entrypoint**: `dot_zshenv` acts as an XDG bootloader for instant environment setup.
- **Modern toolchain**: Replaces classic Unix tools with high-performance Rust alternatives:
  - `ls` → `eza`
  - `cat` → `bat`
  - `grep` → `ripgrep`
  - `cd` → `zoxide` (smart directory jumping)
  - `history` → `atuin` (syncable, encrypted SQLite history)
- **Predictive shell**:
  - **AI strategy**: Context-aware autosuggestions coupled with optional local LLM integration (`ai_core`).
  - **Error analysis**: Wrappers analyze command failures through `gh copilot` or local models.

### Non-goals
- **Not a framework**: This is a curated distribution, not a plugin manager like Oh-My-Zsh.
- **Not POSIX-pure**: Prioritizes modern Zsh/Rust features over strict POSIX compliance.
- **Not minimal**: Optimizes for functionality and speed, not line-count minimalism.

### Security
- **Hardened by default**: Scripts run with `set -euo pipefail` to fail fast on errors.
- **Supply chain safety**:
  - **Pinned install**: Installation commands pin to the specific release tag (`v0.2.480`) to prevent drift.
  - **Zero-trust**: No implicit reliance on `main` branch code in production.
- **Threat model**: This project assumes a **trusted local machine** and focuses on supply-chain (pinned versions) and configuration safety (immutable history).
- **Audit logging**: Dotfiles logs all `chezmoi` mutations to `~/.local/share/dotfiles.log` for day-2 operations review.

### Changes
- **Migrated**:
  - Shell: `~/.zshrc` now sources generated templates from `~/.config/shell`.
  - Neovim: `~/.config/nvim` fully managed through Lua/Lazy.nvim.
  - Tmux: Modular config consolidated to `~/.dotfiles/dot_tmux.conf`.
- **Packaging**:
  - `Brewfile` (macOS) and `apt-get` (Linux) handled automatically.
- **Structural**:
  - **Renamed**: `dot_config/dotfiles` → `dot_config/shell` for semantic clarity.
  - **Moved**: `bin/` → `dot_local/bin/` for automatic path integration.
  - **Separated**: Install scripts split by OS (Darwin/Linux) for cleaner logic.
- **Layered architecture**: Refactored shell config into explicit layers:
  - `00-core`: Safety/Paths
  - `50-logic`: Functions/Toolchain
  - `90-ux`: Aliases/Theme
- **Trust and reproducibility**:
  - **Pinned formulae**: Generated `Brewfile.lock.json` for strictly reproducible macOS builds.
  - **Binary pinning**: `install.sh` now enforces specific version tags for initial bootstrap.
### Quality
- **Conflict resolution**: Detected and resolved **46 namespace collisions** across all alias modules (Git, Go, Archives, etc.) to ensure zero overlap.
- **Git safety**: Renamed colliding Go aliases (for example, `gr` -> `gor`) to protect core Git commands.
- **Modernization**: Merged `list` into `modern` for a cohesive Rust-based toolchain experience (`eza`, `bat`).
- **Standardization**: Removed duplicate logging functions in favor of a shared utility.
- **Documentation**: All 30+ component READMEs now reflect current functionality.

### Toolchain
- **Kubernetes**: Added `kubectl`, `helm`, `k9s` aliases.
- **IaC**: Added `terraform`, `opentofu`, `ansible`.
- **Languages**: Added ecosystem support for `go`, `yarn`, `uv` (modern Python).
- **AI integration**: Added wrappers for `gh copilot`, `fabric`, and local LLMs.
- **Smart help**: Added `dothelp` to search and index custom functions.

### Testing

- **Automated testing**
  - Docker CI (`ci-docker.yml`) runs on Ubuntu/Fedora/Arch.
  - Integration tests validate alias syntax (`test-aliases.sh`).

- **Enterprise core and security (the trust layer)**
  - **SLSA and SBOM**: `security-release.yml` generates SPDX SBOMs and SLSA Level 3 Provenance.
  - **Signing**: `enable-signing` wizard for GPG/SSH git signing.
  - **Immutability**: `lock-configs` / `unlock-configs` protect critical dotfiles (`chflags`/`chattr`).

- **Legal and licensing**
  - **Compliance**: `scan-licenses` (FOSSology/Trivy), `check-cla` (GitHub checks).
  - **Attribution**: `add-headers` automation and `gen-notice` generation.

- **Self-healing and diagnostics**
  - **Health**: `dot doctor` diagnoses environment (dependencies, XDG, paths).
  - **Repair**: `dot heal` / `dot drift` aliases for auto-repair and drift detection.

- **Regulatory compliance**
  - **Documentation**: `COMPLIANCE.md` maps features to **SOC2 Type II** and **ISO 27001**.
  - **Privacy**: `privacy-mode` alias disables CLI telemetry for 7+ frameworks.

- **macOS deep integration**
  - **Hardening**: `defaults` script hardens screensaver, firewall, and Finder settings.
  - **Optimization**: Configures Safari for development, removes Dock clutter.

- **Font typography**
  - **Fonts**: Auto-installs `JetBrainsMono Nerd Font` and `Symbols Nerd Font`.
  - **Rendering**: Linux `fontconfig` XML for sub-pixel antialiasing.

- **Phase 58: Editor unification** (implemented)
  - **Neovim IDE**: Full VS Code feature parity (Noice, Lualine, Gitsigns, Indent-Blankline).
  - **Language support**: Optimized for Rust (Rustaceanvim) and Python (BasedPyright/Ruff).
  - **Performance**: Lazy-loading architecture with `<30ms` startup.
  - **CI/CD fixes**: Resolved CodeQL alerts (removed legacy Node.js) and fixed Docker builds.

- **OS bundling and compliance**
  - **Packaging**: `scripts/package.sh` generates versioned distribution tarballs.
  - **Enterprise**: `/etc/dotfiles/defaults.d` hooks for site-local config overrides.
  - **Standards**: Strict **XDG Base Directory** enforcement in `paths.sh`.

- **The universal installer (zero-dep)**
  - **Bootstrap**: `install.sh` runs through `curl | sh` with no dependencies.
  - **Teleport**: `dot teleport user@host` deploys configs ephemerally through SSH.

### Verification
- **Performance**: Benchmark script `scripts/benchmark.sh` confirms <20ms startup.
- **Integration**: `test-aliases.sh` validates syntax of all 32 alias modules.
- **Security**: **Zero critical vulnerabilities** (CodeQL and Dependabot clean).
- **Functionality**: Local migration tested on macOS, Linux, and WSL.


### Install and migrate

#### Option A: Fresh install (new machines)
To set up a new machine, run the universal installer:
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.480/install.sh)"
```

#### Option B: Migration (upgrade from earlier versions)

> [!IMPORTANT]
> This release changes the architecture from direct symlinks to `chezmoi` templates. Back up your configuration first.

Existing `chezmoi` users can run `chezmoi apply` to upgrade, but the full installer works better for major version jumps.

1. **Back up legacy configs**:
   ```bash
   mv ~/.zshrc ~/.zshrc.bak
   mv ~/.config/nvim ~/.config/nvim.bak
   ```
2. **Run the installer**:
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.480/install.sh)"
   ```
3. **Resolve conflicts**:
   - If `chezmoi` prompts you to overwrite files (for example, `.zshrc`), select **overwrite** (or diff to check) because this release uses a new sourcing strategy.
4. **Restart shell**:
   ```bash
   exec zsh
   ```
