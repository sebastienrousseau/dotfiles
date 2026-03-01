# 🏛️ Architecture & System Design

This document outlines the core architectural decisions and system design of the **Dotfiles Shell Distribution (v{{ .dotfiles_version }})**. This is not just a configuration; it is a high-performance, modular infrastructure for your terminal.

---

## 🏗️ Core Philosophy

*   **XDG-First**: Configuration strictly adheres to the `~/.config/` (XDG Base Directory) specification to prevent home directory clutter.
*   **Polyglot & Multi-Shell**: First-class support for **Zsh**, **Fish**, and **Nushell**, sharing a unified logic core.
*   **Zero-Cost Startup**: Heavy features are deferred or autoloaded to ensure the first prompt appears in **< 10ms**.
*   **Deterministic & Declarative**: Leveraging **Nix Flakes** for bit-for-bit identical environments across machines.
*   **Async-by-Design**: Background daemons (**Pueue**) handle heavy mutations (upgrades, builds) without blocking the user.

---

## 📐 System Layout

```text
~/.dotfiles/
├── dot_config/          # Managed application configurations (~/.config/)
│   ├── zsh/             # Modular Zsh rc.d architecture
│   ├── fish/            # Autoloading Fish configuration
│   ├── nushell/         # Structured data shell config
│   ├── shell/           # Shared logic (aliases, paths, functions)
│   └── ...              # 50+ tool configurations (nvim, tmux, ghostty, etc.)
├── dot_local/           # Local binaries and scripts (~/.local/bin)
├── .chezmoitemplates/   # Unified source for aliases, functions, and paths
├── nix/                 # Nix Flake for deterministic toolchains
├── lib/wasm-tools/      # Rust source for high-performance Wasm utilities
└── install.sh           # Universal, zero-dependency bootstrap script
```

---

## 🐚 Shell Startup Strategies

Each shell utilizes a different strategy to achieve "Ultimate Performance":

### ⚡ Zsh: Modular Deferred Loading
Zsh uses a tiered `rc.d` approach combined with `zinit` turbo mode.
1.  **Phase 0 (Bootload)**: `.zshenv` sets XDG paths and essential `$PATH`.
2.  **Phase 1 (Core)**: `.zshrc` loads environment and basic options.
3.  **Phase 2 (Deferred)**: Heavy tool aliases and plugins are loaded *after* the first prompt via a `precmd` hook.

### 🐟 Fish: Dynamic Function Autoloading
To avoid the cost of parsing a 200+ line alias file at startup, we use a **Transformation Pipeline**:
1.  **Source**: Aliases are defined in `.chezmoitemplates/aliases/`.
2.  **Build**: A Chezmoi `run_onchange` script parses these aliases.
3.  **Output**: Every alias is converted into a standalone `~/.config/fish/functions/<name>.fish` file.
4.  **Runtime**: Fish **never** reads these files until you actually type the command, resulting in a near-instant startup.

### 📊 Nushell: Structured Data Pipeline
Nushell treats the shell as a data processor.
1.  **Environment**: `env.nu` handles path and cross-platform detection.
2.  **Logic**: `config.nu` implements wrappers and data-aware aliases (e.g., `ls` returning tables instead of strings).

---

## ❄️ Deterministic Portability (Nix)

We use **Nix Flakes** to provide a consistent toolchain across macOS and Linux.
*   **`flake.nix`**: Defines the exact versions of every tool (Neovim, Starship, Yazi, etc.).
*   **`direnv`**: Automatically activates the Nix environment when you enter the dotfiles directory.
*   **Benefits**: Zero configuration drift. If it works in CI, it works on your machine.

---

## ⚙️ Async Task Management (Pueue)

Heavy operations are offloaded to the **Pueue** daemon.
*   **Flow**: User runs `bg-upgrade` → Script submits tasks to Pueue → Shell remains responsive.
*   **Feedback**: The `starship` prompt monitors the Pueue socket and displays a `⚙` icon if tasks are active.

---

## 🧠 Local AI RAG (Retrieval-Augmented Generation)

The `dot-ai` utility implements a local semantic search:
1.  **Retrieve**: Uses `ripgrep` to search your actual dotfile templates and documentation.
2.  **Context**: Chunks the relevant aliases and functions.
3.  **Generate**: Feeds the context into a local LLM (Ollama) or CLI (Mods) to provide personalized help.

---

## 🛡️ Security Architecture

*   **Secrets**: Managed via **Age** (encryption) and **SOPS** (declarative editing).
*   **Audit Trail**: Every mutation or privileged action is logged to `~/.local/share/dotfiles.log`.
*   **Hardening**: Opt-in scripts for Firewall (UFW/socketfilterfw), Telemetry disabling, and DNS-over-HTTPS.

---

**Architecture Version**: 2.0.0 (2026 Edition)
**Status**: Stable / Sublime
