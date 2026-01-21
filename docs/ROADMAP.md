# Product Roadmap: The Trusted Shell Platform

This roadmap steers the project from a "feature-rich dotfiles repo" to an **Enterprise-Grade Shell Distribution**. The structure is organized by strategic pillars (**Trust**, **Predictability**, **Observability**) rather than linear phases, though the original 100-Phase vision is preserved within these categories.

---

## 🏗️ Pillar 1: Reproducibility & Determinism (Highest ROI)
**Goal:** "Reproducible Shell Environments".
> *This distribution aims for deterministic rebuilds: the same tag yields the same environment across machines.*

- [ ] **Pinned Formulae**: Strict version locking for Homebrew bundle and Apt packages.
- [ ] **Binary Locking**: Future versions may replace bootstrap download helpers with checksum-verified artifacts once a portable verification strategy is finalized.
- [ ] **State Capture**: `chezmoi` templates that capture host-specific state for idempotence.
- [ ] **Manifests**: Optional `Brewfile.lock` or equivalent for Linux.
- [ ] **Cloud-Init (Phase 28)**: Generate `user-data` scripts for AWS/GCP bootstrapping.
- [ ] **Container Native (Phase 28)**: Base Docker image for devcontainers.
- [ ] **Terraform Provider (Phase 28)**: Custom provider to provision dotfiles state.

## 👁️ Pillar 2: First-Class Observability
**Goal:** "Observable Shell Lifecycle".
> *The shell is instrumented: failures, timing, and lifecycle events are visible by design.*

- [ ] **Audit Structuring**: JSON-structured logging for bootstrap and provisioning events.
- [ ] **Debug Modes**: First-class support for `DOTFILES_DEBUG=1` and `DOTFILES_TRACE=1`.
- [ ] **Telemetry (Local)**: Granular startup timing breakdown (init vs plugins vs prompt).
- [ ] **Health Dashboard (Phase 39)**: CLI view of system "health" metrics.
- [ ] **System Status (Phase 39)**: Real-time resource usage, battery, and network stats.
- [ ] **Update Manager (Phase 39)**: Visual interface for tool updates and migration.

## 🔐 Pillar 3: Secrets & Trust Boundaries
**Goal:** "Explicit Secrets Model".
> *Secrets are never committed; sensitive state is encrypted or host-local by default.*

- [ ] **Secret Driver**: Native integration with 1Password/Bitwarden CLI via `chezmoi`.
- [ ] **Encryption**: Promoted use of `age` encryption for all private config files.
- [ ] **Leak Prevention (Phase 29)**: Pre-commit hooks (TruffleHog/Gitleaks) for high-entropy detection.
- [ ] **Vault Integration (Phase 29)**: Native HashiCorp Vault support.
- [ ] **Hardware Enclaves (Phase 29)**: Support for Secure Enclave/TPM key storage.
- [ ] **OIDC Auth (Phase 29)**: Keyless authentication via GitHub OIDC.

## 🧱 Pillar 4: Layered Architecture & Toolchain
**Goal:** "Composable Shell Layers".
> *The distribution is layered: core safety is mandatory, advanced features are opt-in.*

- [ ] **Core Layer**: XDG, PATH, Safety (`set -euo pipefail`). (Zero external deps).
- [ ] **UX Layer**: Prompt (Starship), Aliases, Completions.
- [ ] **Toolchain Layer**: Rust replacements (`eza`, `bat`, `ripgrep`).
- [ ] **Cross-Compiler Toolchain (Phase 34)**:
    - [ ] **Multi-Arch**: `qemu-user-static` for ARM64/AMD64.
    - [ ] **Wasm Target**: WebAssembly toolchain setup.
    - [ ] **Embedded Dev**: Presets for Arduino/ESP32.

## ⚙️ Pillar 5: Controlled Opt-In Features
**Goal:** "Explicit Feature Flags".
> *Advanced features are gated behind explicit opt-in flags.*

- [ ] **Feature Toggles**: Environment variables (e.g., `ENABLE_AI=0`, `ENABLE_HISTORY_SYNC=0`).
- [ ] **Lazy Loading**: Strict lazy-loading for all non-core plugins.
- [ ] **Plugin Ecosystem (Phase 35)**:
    - [ ] **Module Registry**: Public index of dotfiles modules.
    - [ ] **Dependency Solving**: Semantic versioning for modules.
    - [ ] **Verified Publishers**: Cryptographic signing for "Official" modules.

## 🛡️ Pillar 6: Threat Model & Safety
**Goal:** "Documented Threat Model".
> *Security decisions are driven by an explicit, documented threat model.*

- [ ] **Threat Model Doc**: A lightweight document defining the trust boundary (Local Machine).
- [ ] **Supply Chain**: Verification steps for upstream dependencies.
- [ ] **Identity & Access (Phase 40)**:
    - [ ] **SSH Certs**: Short-lived SSH Certificates.
    - [ ] **YubiKey Bio**: Biometric enforcement for `sudo`.
    - [ ] **PAM Modules**: Custom auth modules.
    - [ ] **Auditd Rules**: Pre-configured audit rules.

## 🧪 Pillar 7: Self-Test & Validation
**Goal:** "Self-Validating Environment".
> *The environment can validate itself after installation or update.*

- [ ] **Smoke Tests**: Automated verification of key aliases (`ls`, `git`, `docker`).
- [ ] **CI Validation**: GitHub Actions workflow to boot and verify the shell syntax.
- [ ] **Chaos Engineering (Phase 41)**:
    - [ ] **Config Chaos**: Randomly corrupt config files to test recovery.
    - [ ] **Network Simulation**: Simulate high latency/packet loss.
    - [ ] **Permission Fuzzing**: Verify strict umask behavior.

## 📦 Pillar 8: Distribution Guarantees & Platform Support
**Goal:** "Supported Platforms Matrix".
> *Only listed platforms are guaranteed to work; others are best-effort.*

- [ ] **Support Matrix**: Explicit table of OS/Version support (macOS 14+, Ubuntu 24.04+, WSL2).
- [ ] **Windows Deep Integration (Phase 53)**:
    - [ ] **PowerShell Profile**: Mirror Zsh functionality.
    - [ ] **WinGet**: Declarative package management.
    - [ ] **WSL Bridge**: Seamless interop.
- [ ] **Linux Deep Integration (Phase 55)**:
    - [ ] **Systemd User Units**: User service management.
    - [ ] **Desktop Envs**: GNOME/KDE/Sway configs.

---

## 🔮 Future Horizons (Legacy Roadmap)

### Domain-Specific Environments
- [ ] **Data Science (Phase 38)**: Conda/Mamba, GPU Config, Jupyter.
- [ ] **Network Topologies (Phase 56)**: Mesh Networks, Tor, Private VPNs.
- [ ] **Build Systems (Phase 57)**: Bazel, Maven/Gradle, CMake.
- [ ] **Financial Operations (Phase 63)**: Cost CLI, Ledger, Stock Tickers.
- [ ] **Game Development (Phase 64)**: Unity/Unreal CLI, Godot, Blender.
- [ ] **Scientific Computing (Phase 68)**: Latex, R/Julia, Pandoc.
- [ ] **Quantum Computing (Phase 69)**: Qiskit, Simulators.
- [ ] **Bio-Informatics (Phase 70)**: Genomics, PDB, FASTA.

### Enterprise & Operations
- [ ] **Collaborations (Phase 45)**: Pair Programming, Team Sync, ChatOps.
- [ ] **Database DevOps (Phase 46)**: DB Clients, Local Docker DBs, Migrations.
- [ ] **Serverless (Phase 47)**: Lambda, Edge Workers, Wasm.
- [ ] **Enterprise Fleet (Phase 30)**: MDM Profiles, Policy as Code.
- [ ] **Legal & Procurement (Phase 93)**: RFP Templates, Vendor Management.
- [ ] **Recruiting & HR (Phase 94)**: Resume Generators, coding interview sets.

### Accessibility & Legacy
- [ ] **Accessibility (Phase 36)**: Screen Reader optimization, High Contrast.
- [ ] **Legacy Modernization (Phase 42)**: Mainframe/Unix support, PowerShell Core.

---

## 📜 Completed Milestones

### Core Foundations
- [x] **Universal Config (Chezmoi) (Phase 1)**
- [x] **Shell Environment (Phase 2)**
- [x] **Tool Modernization (Phase 3)**
- [x] **Performance Optimization (Phase 4)**

### Hardened Security
- [x] **Security & Validation (Phase 5)**
- [x] **Package Management (Phase 6)**
- [x] **Hardened Security (Phase 21)**
- [x] **Enterprise Core (Phase 23)**: SLSA, SBOM, Signed Releases.
- [x] **Legal & Licensing (Phase 92)**: FOSSology, Headers, CLA.

### Experience
- [x] **Documentation (Phase 25)**: DocSite, Interactive Tour.
- [x] **Self-Healing (Phase 27)**: Doctor, Auto-Repair.
- [x] **OS Bundling (Phase 26)**: XDG Compliance, Vendor Hooks.
- [x] **Predictive Shell (Phase 32)**: Autosuggest, Local LLM.
- [x] **Visual Layer (Phase 34)**: Yazi, Zellij, Ghostty.
