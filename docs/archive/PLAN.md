# Universal Configuration Plan (Chezmoi)

... [Previous Sections Unchanged] ...

# Phase 15: Operational Documentation [COMPLETED]
- [x] **Guide**: Created `OPERATIONS.md`.

# Phase 16: Final Release Verification [COMPLETED]
- [x] **Verification**: All systems passed.

# Phase 17: Structural Optimizations (v0.3.0)

## Goal
Implement structural improvements for better organization and maintainability, anticipating v0.3.0.

## Proposed Changes

### [REFACTOR] Semantic Organization
- **Move**: `dot_config/dotfiles` -> `dot_config/shell`.
- **Reason**: `dotfiles` is redundant inside a dotfiles repo. `shell` describes the content (aliases, paths, functions).
- **Update**: Update references in `dot_zshrc.tmpl` and install scripts.

### [REFACTOR] Script Installation
- **Move**: `bin/` -> `dot_local/bin/`.
- **Reason**: Ensures scripts are automatically installed to `~/.local/bin` (user PATH).

### [CLEANUP] Remove Legacy Files
- **Delete**: `Makefile`, `package.json`.
- **Reason**: Replaced by `chezmoi` and GitHub Actions.

### [REFACTOR] Script Segregation
- **Split**: `run_onchange_install_packages.sh.tmpl` into:
    - `run_onchange_darwin_install-packages.sh.tmpl` (Homebrew)
    - `run_onchange_linux_install-packages.sh.tmpl` (Apt)
    - `run_onchange_after_install-vim-plug.sh.tmpl` (Universal)
- **Reason**: Improves readability and maintainability.

# Phase 18: Component Documentation Polish [COMPLETED]

## Goal
Update component documentation (`aliases`, `functions`, `paths`) to match the new `chezmoi` architecture and ensure accuracy.

## Changes
- **Aliases**: Updated `aliases/README.md` to explain modular `*.aliases.sh` loading.
- **Functions**: Updated `functions/README.md` to remove legacy install instructions.
- **Paths**: Updated `paths/README.md` to clarify precedence and `chezmoi` integration.
- **Cleanup**: Standardized all nested alias READMEs to remove legacy HTML artifacts and restore banners.

# Phase 19: Toolchain Expansion [COMPLETED]

## Goal
Add comprehensive support for modern DevOps/Cloud engineering tools.

## Proposed Changes
### [NEW] Aliases
- **Kubernetes**: `kubectl` shortcuts (`k`), `helm`, `k9s`.
- **IaC**: `terraform` (`tf`), `opentofu`, `ansible`.
- **Languages**: `go` (`g`), `yarn`, `uv` (modern Python).
- **Diagnostics**: `jq`, `yq`, `nc`, `curlie`.
- **Structure**: Each component gets its own directory in `.chezmoitemplates/aliases/` with a standard `README.md`.

# Phase 20: Intelligent Assistance [COMPLETED]

## Goal
Integrate AI capabilities and improved help systems.

## Proposed Changes
### [NEW] Functions
- **`dothelp`**: Index and search all aliases/functions with descriptions.
- **AI Wrappers**: Aliases for `gh copilot`, `fabric`, or generic LLM CLI tools.

# Phase 22: Automated Testing [COMPLETED]

## Goal
Verify the dotfiles work on clean Linux environments.

## Proposed Changes
### [CI] GitHub Actions
- **Container Job**: Run `chezmoi init --apply` inside a localized Docker container (Ubuntu/Fedora) to prove universal compatibility.

# Phase 23: Enterprise Core & Security (The Trust Layer) [COMPLETED]

## Goal
Establish a "Trust Layer" for the dotfiles ecosystem, ensuring supply chain security and configuration integrity.

## Changes
- **SLSA & SBOM**: Implemented `security-release.yml` for provenance and SBOM generation.
- **Signing**: Created `enable-signing` wizard alias for easy GPG/SSH configuration.
- **Immutability**: Created `lock-configs.sh` script and `lock-configs`/`unlock-configs` aliases.

- **Immutability**: Created `lock-configs.sh` script and `lock-configs`/`unlock-configs` aliases.

# Phase 27: Self-Healing & Diagnostics [COMPLETED]

## Goal
Enable the system to self-diagnose and repair configuration drift.

## Changes
- **Scripts**: Created `scripts/diagnostics/doctor.sh` for system health checks.
- **Aliases**: Added `dot doctor`, `dot drift` (`chezmoi verify`), and `dot heal` (`chezmoi apply`).

# Phase 51: Regulatory Compliance [COMPLETED]

## Goal
Document and enforce compliance with SOC2, ISO, and GDPR standards.

## Changes
- **Documentation**: Created `COMPLIANCE.md` with control mappings.
- **Privacy**: Added `privacy-mode` alias to disable CLI telemetry.
- **Audit**: Added `dot audit` alias for tracking changes.

# Phase 54: macOS Deep Integration [COMPLETED]

## Goal
Harden and optimize the macOS environment via code.

## Changes
- **Defaults**: Created `run_onchange_darwin_defaults.sh.tmpl` to apply secure/optimized `defaults`.
- **Hardening**: Enabled screensaver passwords, firewall settings, and disabled guest access.

## Goal
Ensure legal compliance and proper attribution for the open-source project.

## Changes
- **Licensing**: Added `scan-licenses` alias (Trivy/FOSSology).
- **Headers**: Added `add-headers` alias for automated copyright insertion.
- **Compliance**: Added `check-cla` and `gen-notice` tools.

# Phase 59: Font Typography [COMPLETED]

## Goal
Standardize typography and ensure high-quality font rendering across all environments.

## Proposed Changes
- **Nerd Fonts**: Automate installation of `JetBrainsMono Nerd Font` and `Symbols Nerd Font`.
- **Fontconfig**: Deploy XML configuration for Linux font rendering (antialiasing, hinting).
- **Aliases**: `update-fonts` to refresh font caches (`fc-cache`).

# Phase 26: OS Bundling & Compliance [COMPLETED]

## Goal
Prepare the dotfiles for system-wide deployment and ensure strict adherence to standards.

## Proposed Changes
- **XDG Compliance**: Audit `00-default.paths.sh` to ensure all standard XDG variables are exported.
- **Vendor Hooks**: Update `dot_zshrc.tmpl` to source system-level overrides from `/etc/dotfiles/defaults.d/` (Simulates "site-local" config).
- **Bundling**: Create `scripts/core/package.sh` to create a distributable tarball and scaffold `.deb`/`.pkg` generation logic.

# Phase 24: The Universal Installer (Zero-Dependency) [COMPLETED]

## Goal
Provide a frictionless, "one-curl" onboarding experience and capabilities to deploy configurations remotely.

## Proposed Changes
- **install.sh**: A standalone, zero-dependency bash script that:
    1.  Detects OS/Arch.
    2.  Installs `chezmoi` (binary or via package manager).
    3.  Initializes the dotfiles repo.
    4.  Runs `chezmoi apply`.
    5.  Uses ANSI colors for a polished "TUI" feel.
- **Teleportation**: `scripts/ops/teleport.sh` using `chezmoi archive` piped to SSH to ephemeralize configs on remote servers (e.g., `dot teleport user@server`).
