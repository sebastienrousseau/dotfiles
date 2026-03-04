<p align="center">
  <img src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg" alt="Dotfiles logo" width="128" />
</p>

<h1 align="center">.dotfiles</h1>

<p align="center">
  <strong>The Ultimate, 2026-Ready Shell Distribution for Power Users</strong>
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/dotfiles/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/dotfiles/ci.yml?style=for-the-badge&logo=github" alt="Build" /></a>
  <a href="https://github.com/sebastienrousseau/dotfiles/releases/tag/v{{ .dotfiles_version }}"><img src="https://img.shields.io/badge/Version-v{{ .dotfiles_version }}-blue?style=for-the-badge" alt="Version" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License" /></a>
  <a href="https://github.com/sebastienrousseau/dotfiles/releases"><img src="https://img.shields.io/github/downloads/sebastienrousseau/dotfiles/total?style=for-the-badge" alt="Downloads" /></a>
</p>

---

## ✨ Overview

Dotfiles is a **high-performance, idempotent shell distribution** designed for developers who demand speed, security, and reproducibility. Managed by [Chezmoi](https://github.com/twpayne/chezmoi), it provides a sublime terminal experience across **macOS, Linux, and WSL2**.

It's not just a collection of configs—it's a **curated infrastructure** that evolves with you.

---

## 🚀 The 2026 Next-Gen Frontier

While others are still configuring Bash, we are building the future. This repository includes:

*   🏎️ **Zero-Cost Shell Startup**: Advanced `_cached_eval` logic for Zsh, Bash, and Fish, bypassing repetitive tool initializations for near-instant boot times.
*   ❄️ **Nix & Home Manager**: Declarative user environments with full Home Manager support for bit-for-bit identical setups.
*   📊 **Nushell (Data-Driven)**: Process system data as structured tables, not just strings.
*   🧠 **Unified AI Experience**: Centralized identity context (`~/.config/ai/identity.md`) shared across Claude, Gemini, and Aider.
*   ⚙️ **Pueue (Async Daemon)**: Offload heavy tasks (upgrades, builds) to a background queue with native Systemd integration.
*   💎 **WebAssembly (Wasm)**: Run ultra-fast, pre-compiled tools via `wasmtime`.

---

## 📦 Features at a Glance

| Category | Highlights |
| :--- | :--- |
| **Shells** | **Zsh** (Daily), **Fish** (Performance), **Nushell** (Data) |
| **Editors** | **Neovim** (Lua-powered), **Vim** (Legacy-compatible) |
| **UX** | **Starship** (Prompt), **Zoxide** (Jump), **Atuin** (History), **fzf** (Fuzzy) |
| **Discovery** | **Yazi** (Files), **fd** (Find), **Ripgrep** (Search) |
| **Tools** | **Mise** (Runtimes), **Pueue** (Async), **Delta** (Diffs), **Lazygit** (Git TUI) |
| **Security** | **Age** (Enc), **Sops** (Secrets), **Firewall** (Hardening), **Key Rotation** |

---

## ⚡ Quick Start

> [!IMPORTANT]
> The installer automatically backs up any existing dotfiles to `~/.dotfiles.bak.<timestamp>/`.

### 1. The Instant Install
Works on macOS, Linux, and WSL2:

```bash
sh -c "$(curl -fsSL https://dotfiles.io/install.sh)"
```

### 2. Enter the Ecosystem
Once installed, use the `dot` CLI to manage your world:

```bash
dot update    # Sync everything (Git + Chezmoi + Nix + Plugins)
dot tools     # Explore the curated tool catalog
dot-ai "How do I..." # Ask your local AI about your configuration
```

---

## 🛠️ Portability: Nix & Direnv

For the ultimate "reproducible" experience, we use **Nix Flakes**. Typing `cd ~/.dotfiles` instantly injects a perfect, pre-compiled toolchain into your shell.

```bash
# Enter the deterministic shell
nix develop
```

---

## 🏁 Performance Modes

| Mode | Environment Variable | Best For |
| :--- | :--- | :--- |
| **Standard** | (Default) | Full-featured daily driver. |
| **Fast** | `DOTFILES_FAST=1` | High-speed setup with essential tools. |
| **Ultra** | `DOTFILES_ULTRA_FAST=1` | Minimalist startup (< 1ms) for high-frequency work. |

---

## 📚 Documentation Deep-Dives

- [📂 Tools Catalog](docs/TOOLS.md) — Comprehensive list of all integrated packages.
- [🏛️ Architecture](docs/ARCHITECTURE.md) — How the shell startup, caching, and templates work.
- [🔐 Security & Secrets](docs/SECRETS.md) — Hardening, encryption, and Age/Sops setup.
- [🧠 AI Integrations](docs/AI.md) — Setting up Claude, Gemini, and Aider.
- [⚙️ Operations](docs/OPERATIONS.md) — Daily workflows and maintenance.
- [🆘 Troubleshooting](docs/TROUBLESHOOTING.md) — Common fixes and platform notes.

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](.github/CONTRIBUTING.md) and [Code of Conduct](.github/CODE_OF_CONDUCT.md).

---

## 📜 License

Licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

<p align="right"><a href="#dotfiles">↑ Back to Top</a></p>
