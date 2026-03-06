# 🏛️ Architecture & System Design

This document outlines the core architectural decisions and system design of the **Dotfiles Shell Distribution (v{{ .dotfiles_version }})**. This is not just a configuration; it is a high-performance, modular infrastructure for your terminal.

---

## 🏗️ Core Philosophy

*   **XDG-First**: Configuration strictly adheres to the "~/.config/" (XDG Base Directory) specification to prevent home directory clutter.
*   **Polyglot & Multi-Shell**: First-class support for **Zsh**, **Fish**, and **Nushell**, sharing a unified logic core.
*   **Zero-Cost Startup**: Heavy features are deferred or autoloaded to ensure the first prompt appears in **< 10ms**.
*   **Deterministic & Declarative**: Leveraging **Nix Flakes** for bit-for-bit identical environments across machines.
*   **Async-by-Design**: Background daemons (**Pueue**) handle heavy mutations (upgrades, builds) without blocking the user.

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
├── scripts/             # Internal libraries and diagnostics
│   └── dot/lib/bento.sh # 2026 Intelligence Surface renderer
├── nix/                 # Nix Flake for deterministic toolchains
├── lib/wasm-tools/      # Rust source for high-performance Wasm utilities
└── install.sh           # Universal, zero-dependency bootstrap script
```

---

## 🐚 Shell Startup Strategies

### 🏎️ Shared: Unified `_cached_eval` Logic
Across Zsh, Fish, and Bash, we implement an idempotent caching wrapper for external tool initializations (Starship, Zoxide, Atuin).
1.  **Intercept**: The shell checks if a cached version of the tool's `eval` output exists in `~/.cache/shell/`.
2.  **Validate**: It compares the cache timestamp against the tool binary.
3.  **Bypass**: If valid, the shell `source`s the text file directly, avoiding a subshell execution and saving **20-50ms** per tool.

### ⚡ 2026 Edition: Zero-Jank & Lazy-Hydration
To achieve the "Apple-Standard" fluid threshold (~16ms), we have implemented a **Lazy-Hydration** model:
1.  **Phase 1 (Visual Paint)**: The shell prompt (`➜ `) is rendered immediately using static escape codes.
2.  **Phase 2 (Async Hydration)**: Tool initializations (mise, atuin, etc.) are dispatched to background workers (`&!`).
3.  **Phase 3 (On-Demand Activation)**: Environment hydration only occurs upon the first user interaction (Enter or Prompt paint) or after 500ms of idle time. This ensures total execution time stays below 50ms.

---

## 💎 The Canvas: Artifact-Only Mode

A premium "Consumer-First" environment triggered by `DOTFILES_ARTIFACT_MODE=1`.
*   **Minimalist UI**: Strips all prompt complexity, leaving only a green `➜ `.
*   **Intelligence Surface**: An asynchronous Bento-style dashboard rendered via `bento.sh` that provides environmental context (Node version, Cloud status, Git health) without blocking the main thread.
*   **Redraw Signaling**: Uses `SIGWINCH` to smoothly return control to the user after background hydration completes.

---

**Architecture Version**: 3.0.0 (2026 Euxis Evolution)
**Status**: Stable / Sublime
