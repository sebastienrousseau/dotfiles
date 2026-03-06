# 🛠️ The Sublime Tool Catalog

Welcome to the definitive collection of high-performance tools integrated into your dotfiles. This catalog categorizes every utility by its role in your workflow, focusing on **speed, ergonomics, and 2026-ready innovation**.

---

## 🐚 Core Shells
The engines that power your terminal experience.

| Icon | Tool | Purpose | Key Feature |
| :--- | :--- | :--- | :--- |
| ⚡ | **Zsh** | The Daily Driver | Modular `rc.d` architecture with advanced lazy-loading. |
| 🐟 | **Fish** | The Friendly Shell | **Zero-cost startup** via dynamic alias-to-function autoloading. |
| 📊 | **Nushell** | The Data Shell | Structured data pipelines. Think SQL meets Bash. |
| 🚀 | **Starship** | The Universal Prompt | Ultra-fast, cross-shell prompt with async background task indicators. |

---

## 🏗️ Infrastructure & Portability
Ensuring your environment is deterministic and reproducible anywhere.

| Icon | Tool | Category | Description |
| :--- | :--- | :--- | :--- |
| ❄️ | **Nix Flakes** | Deterministic Ops | Bit-for-bit identical environments via `flake.nix`. |
| 🏠 | **Chezmoi** | Dotfiles Manager | Secure, template-based configuration management. |
| 🪄 | **Direnv** | Env Management | Instant environment injection when you `cd` into a directory. |
| 📦 | **Mise** | Runtime Manager | Polyglot version manager (Node, Python, Rust, Go, etc.). |

---

## ⚡ 2026 Next-Gen Frontier
Cutting-edge utilities for the ultimate power user.

| Icon | Tool | Purpose | Why it's Sublime |
| :--- | :--- | :--- | :--- |
| ⚙️ | **Pueue** | Async Daemon | Offload long-running tasks (upgrades, builds) to a background queue. |
| 🧠 | **Dot-AI (RAG)** | AI Assistant | Local semantic search over your own dotfiles using ripgrep + LLMs. |
| 💎 | **Wasmtime** | Wasm Runtime | Run pre-compiled Rust/Zig tools as ultra-fast WebAssembly modules. |
| 💎 | **Atomic Surface** | Intelligence | High-fidelity, async Bento-Grid dashboard for environment context. |
| 🔐 | **SOPS** | Secrets Ops | Declarative, encrypted secrets management integrated with Nix. |

---

## 📂 Navigation & Discovery
Stop searching, start finding.

| Icon | Tool | Description | Pro Tip |
| :--- | :--- | :--- | :--- |
| 🦖 | **Yazi** | Terminal File Manager | Use `yy` to instantly `cd` on exit. |
| 🔍 | **Ripgrep (rg)** | Fast Text Search | The gold standard for code searching. |
| 📁 | **fd** | Simple Find | Faster and more intuitive than the legacy `find`. |
| 🗺️ | **Zoxide** | Smart Jump | Replaces `cd` with a fuzzy-learning navigation engine. |
| 🔭 | **fzf** | Fuzzy Finder | Interactive filtering for everything (files, history, git). |

---

## 📝 Modern CLI Replacements
Rust-powered upgrades for classic Unix commands.

| Classic | Modern Replacement | Why? |
| :--- | :--- | :--- |
| `ls` | **eza** | Icons, git status integration, and better colors. |
| `cat` | **bat** | Syntax highlighting and Git integration. |
| `top` | **btop** | Stunning visual dashboards for system resources. |
| `df` | **duf** | User-friendly disk usage overview. |
| `du` | **dust** | Instant visual breakdown of folder sizes. |
| `ps` | **procs** | Modern process tracking with better columns. |

---

## 🎨 Terminal Ecosystem
Where you spend your time.

| Tool | Style | Platform |
| :--- | :--- | :--- |
| **Ghostty** | Native / GPU | macOS, Linux |
| **Zellij** | Modern Multiplexer | Cross-platform (layout-aware) |
| **Tmux** | Classic Multiplexer | The reliable standard |
| **Fastfetch** | System Info | Fast, modern system summary |

---

## 🤖 AI Pair Programming
Integrated AI helpers for the terminal.

*Detailed guide available in [AI.md](AI.md).*

| Tool | Alternative | Description |
| :--- | :--- | :--- |
| **Aider** | aider | Git-native AI pair programming. |
| **Claude CLI** | claude | Anthropic's high-speed assistant. |
| **Kiro CLI** | kiro-cli | Agentic AI terminal assistant. |
| **Gemini CLI** | gemini | Google's multi-modal CLI tool. |
| | sgpt | shell-gpt |
| | ollama | ollama |
| **Mods/Fabric** | mods | Pipeline-friendly AI processing. |

---

## 🛠️ Developer Toolchain
*   **Neovim**: Hyper-optimized Lua-based configuration.
*   **Lazygit**: The best TUI for Git workflows.
*   **Delta**: Beautiful, syntax-highlighted side-by-side diffs.
*   **Just**: Modern task runner (replaces complex Makefiles).

---

## 🔐 Security & Secrets
*   **Age**: Modern, small encryption tool.
*   **GnuPG**: The standard for PGP.
*   **Sops**: Secret editing with automatic encryption.

---

**Last Updated**: 2026-03-01
**Dotfiles Version**: v{{ .dotfiles_version }}
