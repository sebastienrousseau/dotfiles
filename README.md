<p align="center">
  <img src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg" alt="Dotfiles logo" width="128" />
</p>

<h1 align="center">.dotfiles</h1>

<p align="center">
  <strong>Cross-platform shell configuration for macOS, Linux, and WSL. Managed by Chezmoi.</strong>
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/dotfiles/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/dotfiles/ci.yml?style=for-the-badge&logo=github" alt="Build" /></a>
  <a href="https://github.com/sebastienrousseau/dotfiles/releases/latest"><img src="https://img.shields.io/badge/Version-v0.2.494-blue?style=for-the-badge" alt="Version" /></a>
  <a href="https://github.com/sebastienrousseau/dotfiles/releases"><img src="https://img.shields.io/github/downloads/sebastienrousseau/dotfiles/total?style=for-the-badge" alt="Downloads" /></a>
  <a href="https://codespaces.new/sebastienrousseau/dotfiles"><img src="https://github.com/codespaces/badge.svg" alt="Open in GitHub Codespaces" /></a>
</p>

---

## Overview

A reliable, idempotent shell environment for developers who need consistency across machines. Chezmoi manages templates, feature flags, and platform differences so you get the same setup on every device.

- **Telemetry disabled by default** — no data leaves your machine
- **Encrypted secrets** via Age/SOPS — no plaintext credentials in the repo
- **Isolated runtimes** through Mise and Nix — nothing installed system-wide
- **Built-in verification** with `dot doctor` and `dot smoke-test`
- **Atomic backups** on every apply (`~/.dotfiles.bak`)

---

## Architecture

Run once or a hundred times — the result is the same.

```mermaid
graph TD
    A[User Shell] --> B{dot CLI}
    B --> C[Diagnostics: dot doctor/smoke-test]
    B --> D[Maintenance: dot update/prewarm]
    B --> E[Lifecycle: dot apply/rollback]
    D --> F[Chezmoi Source]
    F --> G[Zsh/Fish/Bash Configs]
    F --> H[Tool Runtimes: Mise/Nix]
    G --> I[~/.cache/shell: Fast-Init]
```

---

## Quick Start

Works on macOS, Linux (Debian/Ubuntu/Arch), and WSL2.

### Prerequisites

- Git 2.30+
- curl
- SSH key configured in GitHub (for signed commits)

### Install

Get started in seconds. Run the universal installer to provision your environment. The script detects your OS and configures the appropriate shims.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

For non-interactive use (CI/CD):

```bash
DOTFILES_SILENT=1 DOTFILES_NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

### Verify

```bash
dot doctor
```

### Update

```bash
dot update
```

---

## The `dot` CLI

| Command | Action |
| :--- | :--- |
| `dot apply` | Propagate configuration changes |
| `dot update` | Pull latest changes and pre-warm caches |
| `dot doctor` | Validate paths, versions, and security |
| `dot smoke-test` | Verify toolchain (Rust, Go, AI tools) |
| `dot bundle` | Create an offline portable archive |

---

## What's Included

<details>
<summary><b>Shells</b></summary>

- **Zsh** — primary shell with modular deferred loading
- **Fish** — fast shell with `_cached_eval` startup optimization
- **Nushell** — structured data processing through shell pipelines
- **Starship** — cross-shell prompt showing only what matters
- **Zoxide** — directory jumper that learns your habits
- **Atuin** — searchable shell history synced across machines
</details>

<details>
<summary><b>Development and Runtimes</b></summary>

- **Mise** — polyglot runtime manager (Node, Python, Go, Rust)
- **Nix Flakes** — declarative, reproducible toolchains
- **Home Manager** — full environment state management
- **Pueue** — background task queue for long-running jobs
</details>

<details>
<summary><b>Security</b></summary>

- **Age and SOPS** — secret encryption at rest
- **Signed commits** — SSH/GPG signing enforced
- **Audit logs** — every `dot` command logged to `~/.local/share/dotfiles.log`
- **Telemetry controls** — OS-level telemetry disabled out of the box
</details>

---

**THE ARCHITECT** ᛫ [Sebastien Rousseau](https://sebastienrousseau.com)
**THE ENGINE** ᛞ [EUXIS](https://euxis.co) ᛫ Enterprise Unified Execution Intelligence System

---

## License

Licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

<p align="right"><a href="#dotfiles">Back to Top</a></p>
