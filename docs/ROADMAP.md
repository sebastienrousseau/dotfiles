# Product Roadmap: The Trusted Shell Platform

This roadmap steers the project from a "feature-rich dotfiles repo" to an **Enterprise-Grade Shell Distribution**. The focus is on **Trust**, **Predictability**, and **Contributor Leverage**.

## 1. 📌 Reproducibility & Determinism (Highest ROI)
**Goal:** "Reproducible Shell Environments".
> *This distribution aims for deterministic rebuilds: the same tag yields the same environment across machines.*

- [ ] **Pinned Formulae**: Strict version locking for Homebrew bundle and Apt packages.
- [ ] **Binary Locking**: Sha256 verification for all binary downloads in `install.sh`.
- [ ] **State Capture**: `chezmoi` templates that capture host-specific state for idempotence.
- [ ] **Manifests**: Optional `Brewfile.lock` or equivalent for Linux.

## 2. 🔍 First-Class Observability
**Goal:** "Observable Shell Lifecycle".
> *The shell is instrumented: failures, timing, and lifecycle events are visible by design.*

- [ ] **Audit Structuring**: JSON-structured logging for bootstrap and provisioning events.
- [ ] **Debug Modes**: First-class support for `DOTFILES_DEBUG=1` and `DOTFILES_TRACE=1`.
- [ ] **Telemetry (Local)**: Granular startup timing breakdown (init vs plugins vs prompt).
- [ ] **Health Dashboard**: A CLI view of the system's "health" metrics.

## 3. 🔐 Secrets & Trust Boundaries
**Goal:** "Explicit Secrets Model".
> *Secrets are never committed; sensitive state is encrypted or host-local by default.*

- [ ] **Secret Driver**: Native integration with 1Password/Bitwarden CLI via `chezmoi`.
- [ ] **Encryption**: Promoted use of `age` encryption for all private config files.
- [ ] **Leak Prevention**: Pre-commit hooks to scan for high-entropy strings.
- [ ] **Policy Docs**: Clear documentation on "Public vs Private" config separation.

## 4. 🧱 Layered Architecture
**Goal:** "Composable Shell Layers".
> *The distribution is layered: core safety is mandatory, advanced features are opt-in.*

- [ ] **Core Layer**: XDG, PATH, Safety (`set -euo pipefail`). (Zero external deps).
- [ ] **UX Layer**: Prompt (Starship), Aliases, Completions.
- [ ] **Toolchain Layer**: Rust replacements (`eza`, `bat`, `ripgrep`).
- [ ] **AI Layer**: Optional, lazy-loaded predictive features.

## 5. ⚙️ Controlled Opt-In Features
**Goal:** "Explicit Feature Flags".
> *Advanced features are gated behind explicit opt-in flags.*

- [ ] **Feature Toggles**: Environment variables (e.g., `ENABLE_AI=0`, `ENABLE_HISTORY_SYNC=0`).
- [ ] **Lazy Loading**: Strict lazy-loading for all non-core plugins.
- [ ] **Defaults**: "Safe by default" configuration (minimal network, max privacy).

## 6. 📄 Threat Model & Safety
**Goal:** "Documented Threat Model".
> *Security decisions are driven by an explicit, documented threat model.*

- [ ] **Threat Model Doc**: A lightweight document defining the trust boundary (Local Machine).
- [ ] **Supply Chain**: Verification steps for upstream dependencies.
- [ ] **Isolation**: Documentation on isolation from the host OS (where possible).

## 7. 🧪 Self-Test & Validation
**Goal:** "Self-Validating Environment".
> *The environment can validate itself after installation or update.*

- [ ] **Smoke Tests**: Automated verification of key aliases (`ls`, `git`, `docker`).
- [ ] **CI Validation**: GitHub Actions workflow to boot and verify the shell syntax.
- [ ] **Doctor Upgrade**: `dot doctor` checks for broken symlinks or path collisions.

## 8. 📦 Distribution Guarantees
**Goal:** "Supported Platforms Matrix".
> *Only listed platforms are guaranteed to work; others are best-effort.*

- [ ] **Support Matrix**: Explicit table of OS/Version support (macOS 14+, Ubuntu 24.04+, WSL2).
- [ ] **Deprecation Policy**: Clear timeline for dropping support for old OS versions.

## 9. 📈 Evolution Policy
**Goal:** "Change & Stability Guarantees".
> *Breaking changes are rare, documented, and versioned.*

- [ ] **SemVer**: Strict Semantic Versioning for the release tags.
- [ ] **Changelog**: Automated, categorization of user-facing changes.
- [ ] **Migration Scripts**: Automated helpers for breaking changes.

---

## 📜 Completed Milestones (Legacy "Phases")

### Core Foundations
- [x] **Universal Config (Chezmoi)**: Migrated to template-based system.
- [x] **Modern Tooling**: Replaced legacy Unix tools with Rust equivalents (`eza`, `bat`, `zoxide`).
- [x] **Startup Speed**: Optimized Zsh startup to <20ms.

### Security
- [x] **Audit Logging**: Basic logging of `chezmoi` apply events.
- [x] **Compliance**: SOC2/ISO mapping documentation.
- [x] **Verification**: GPG/SSH signing for commits and releases.

### Integration
- [x] **macOS Hardening**: `defaults` scripting.
- [x] **Docker CI**: Automated build testing.
- [x] **AI**: Initial `ai_core` local LLM wrapper.
