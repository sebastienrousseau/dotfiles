# Tools

Integrated tools organized by role in the workflow.

---

## Core Shells

| Tool | Purpose | Key Feature |
| :--- | :--- | :--- |
| **Zsh** | Primary shell | Modular `rc.d` architecture with lazy-loading |
| **Fish** | Interactive shell | Fast startup via dynamic alias-to-function autoloading |
| **Nushell** | Data shell | Structured data pipelines |
| **Starship** | Cross-shell prompt | Async background task indicators |

---

## Infrastructure and Portability

| Tool | Category | Description |
| :--- | :--- | :--- |
| **Nix Flakes** | Deterministic environments | Bit-for-bit identical setups via `flake.nix` |
| **Chezmoi** | Dotfiles manager | Secure, template-based configuration management |
| **Direnv** | Environment management | Automatic environment injection on `cd` |
| **Mise** | Runtime manager | Polyglot version manager (Node, Python, Rust, Go) |

---

## Automation and Advanced Tools

| Tool | Purpose | Description |
| :--- | :--- | :--- |
| **Pueue** | Task queue | Offload long-running tasks to a background daemon |
| **Wasmtime** | Wasm runtime | Run pre-compiled Rust/Zig tools as WebAssembly modules |
| **SOPS** | Secrets operations | Declarative encrypted secrets management |

---

## Navigation and Discovery

| Tool | Description |
| :--- | :--- |
| **Yazi** | Terminal file manager — use `yy` to `cd` on exit |
| **Ripgrep (rg)** | Fast recursive text search |
| **fd** | Faster, simpler alternative to `find` |
| **Zoxide** | Fuzzy directory jumper (replaces `cd`) |
| **fzf** | Interactive fuzzy finder for files, history, and git |

---

## Modern CLI Replacements

| Classic | Replacement | Improvement |
| :--- | :--- | :--- |
| `ls` | **eza** | Icons, git status, better colors |
| `cat` | **bat** | Syntax highlighting and git integration |
| `top` | **btop** | Visual system resource dashboard |
| `df` | **duf** | Readable disk usage overview |
| `du` | **dust** | Visual breakdown of folder sizes |
| `ps` | **procs** | Improved process tracking |

---

## Terminal Ecosystem

| Tool | Style | Platform |
| :--- | :--- | :--- |
| **Ghostty** | Native / GPU | macOS, Linux |
| **Zellij** | Layout-aware multiplexer | Cross-platform |
| **Tmux** | Classic multiplexer | Cross-platform |
| **Fastfetch** | System info | Cross-platform |

---

## AI Pair Programming

Detailed guide: [AI.md](AI.md).

| Tool | Description |
| :--- | :--- |
| **Aider** | Git-native AI pair programming |
| **Claude CLI** | Anthropic's terminal assistant |
| **Kiro CLI** | Agentic AI terminal assistant |
| **Gemini CLI** | Google's multi-modal CLI tool |
| **Mods/Fabric** | Pipeline-friendly AI processing |
| sgpt | shell-gpt |
| ollama | ollama |

---

## Developer Toolchain

- **Neovim** — Lua-based configuration with lazy.nvim
- **Lazygit** — TUI for Git workflows
- **Delta** — syntax-highlighted side-by-side diffs
- **Just** — modern task runner (replaces Makefiles)

---

## Security and Secrets

- **Age** — modern file encryption
- **GnuPG** — PGP standard
- **SOPS** — secret editing with automatic encryption
