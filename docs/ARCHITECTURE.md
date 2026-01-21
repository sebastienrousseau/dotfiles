# Architecture & Design

v0.2.471 constitutes a portable **Shell Distribution** managed by `chezmoi`. This document outlines the core architectural decisions and system design.

## 1. Core Philosophy

- **XDG-First**: configuration is strictly mapped to `~/.config/` (XDG Base Directory specification). We avoid `~/.foo` file sprawl in the home directory.
- **Single Entrypoint**: `dot_zshenv` acts as the "Bootloader". It is loaded by Zsh immediately and sets up the environment (XDG variables, PATH) before any other initialization occurs.
- **Zero-Dependency Bootstrap**: The installation process relies only on `curl` and `git` (and `chezmoi`, which it self-installs).

## 2. Directory Structure

The repository follows standard `chezmoi` conventions:

```text
~/.local/share/chezmoi/
├── dot_config/          # Mapped to ~/.config/
│   ├── atuin/           # Shell history
│   ├── ghostty/         # Terminal emulator
│   ├── shell/           # Core shell logic (aliases, functions)
│   ├── nvim/            # Neovim IDE configuration
│   └── zsh/             # Zsh specific config
├── dot_local/           # Mapped to ~/.local/
│   └── bin/             # User scripts (added to PATH)
├── dot_zshenv           # The Environment Bootloader
├── .chezmoitemplates/   # Reusable logic blocks
└── install.sh           # Universal bootstrapping script
```

## 3. Modern Toolchain

We replace distinct Unix legacy tools with high-performance Rust alternatives:

| Legacy | Modern Replacement | Purpose |
| :--- | :--- | :--- |
| `ls` | `eza` | Modern file listing with git integration |
| `cat` | `bat` | Syntax highlighted file viewing |
| `grep` | `ripgrep` (`rg`) | Blazing fast search |
| `cd` | `zoxide` | Smart directory jumping |
| `history` | `atuin` | Syncable, encrypted SQLite history |
| `find` | `fd` | User-friendly filesystem search |
| `vim` | `neovim` | Lua-extensible IDE |

## 4. Predictive Shell Strategy

- **AI Integration**: The shell is "AI Aware" via the `ai_core` wrapper.
- **Autosuggestions**: Context-aware completion based on shell history.
- **Error Analysis**: Hooks to send failed command context to local LLMs or GitHub Copilot for explanation.

## 5. Security Posture

- **Hardened Defaults**: Shell scripts run with `set -euo pipefail` to fail fast.
- **Supply Chain Safety**:
  - **Pinned Installation**: Installers reference specific Git tags (e.g., `v0.2.471`), not `main`.
  - **Immutable History**: Logic logic is version controlled and reviewable via `chezmoi diff`.
- **Audit Logging**: All mutations are logged to `~/.dotfiles_audit.log`.

## 6. Compatibility

- **macOS**: Full support (Homebrew, defaults).
- **Linux**: Debian/Ubuntu support (apt-get).
- **Windows**: WSL2 support.
