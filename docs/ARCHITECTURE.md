# How it works

v0.2.474 constitutes a portable **Shell Distribution** managed by `chezmoi`. This document outlines the core architectural decisions and system design.

## Core philosophy

- **XDG-First**: configuration is strictly mapped to `~/.config/` (XDG Base Directory specification). We avoid `~/.foo` file sprawl in the home directory.
- **Single Entrypoint**: `dot_zshenv` acts as the "Bootloader". It is loaded by Zsh immediately and sets up the environment (XDG variables, PATH) before any other initialization occurs.
- **Zero-Dependency Bootstrap**: The installation process relies only on `curl` and `git` (and `chezmoi`, which it self-installs).

## Architecture Diagram

```
                                    DOTFILES ARCHITECTURE
    ================================================================================

    ┌─────────────────────────────────────────────────────────────────────────────┐
    │                              INSTALLATION                                     │
    │  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐              │
    │  │  curl    │───▶│ install  │───▶│ chezmoi  │───▶│  apply   │              │
    │  │          │    │   .sh    │    │  init    │    │          │              │
    │  └──────────┘    └──────────┘    └──────────┘    └──────────┘              │
    └─────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │                              SHELL STARTUP                                    │
    │                                                                               │
    │  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐              │
    │  │ .zshenv  │───▶│ .zshrc   │───▶│ aliases  │───▶│functions │              │
    │  │(bootload)│    │          │    │          │    │          │              │
    │  └──────────┘    └──────────┘    └──────────┘    └──────────┘              │
    │       │                                                                       │
    │       ▼                                                                       │
    │  ┌──────────┐                                                                │
    │  │ XDG vars │                                                                │
    │  │  PATH    │                                                                │
    │  └──────────┘                                                                │
    └─────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │                           CONFIGURATION LAYERS                               │
    │                                                                               │
    │  ┌─────────────────────────────────────────────────────────────────────┐    │
    │  │                         ~/.config/                                    │    │
    │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │    │
    │  │  │  nvim  │ │  git   │ │ shell  │ │ghostty │ │  tmux  │           │    │
    │  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘           │    │
    │  └─────────────────────────────────────────────────────────────────────┘    │
    │                                                                               │
    │  ┌─────────────────────────────────────────────────────────────────────┐    │
    │  │                         ~/.local/bin/                                │    │
    │  │  ┌────────┐ ┌────────┐ ┌────────┐                                  │    │
    │  │  │  dot   │ │scripts │ │ utils  │                                  │    │
    │  │  └────────┘ └────────┘ └────────┘                                  │    │
    │  └─────────────────────────────────────────────────────────────────────┘    │
    └─────────────────────────────────────────────────────────────────────────────┘

```

## Directory structure

The repository follows standard `chezmoi` conventions:

```text
~/.dotfiles/
├── dot_config/          # Mapped to ~/.config/
│   ├── atuin/           # Shell history
│   ├── ghostty/         # Terminal emulator
│   ├── shell/           # Core shell logic (aliases, functions)
│   ├── nvim/            # Neovim IDE configuration
│   ├── tmux/            # Terminal multiplexer
│   ├── git/             # Git configuration
│   ├── lazygit/         # Lazygit TUI
│   ├── mycli/           # MySQL CLI
│   ├── mongosh/         # MongoDB Shell
│   ├── redis/           # Redis CLI
│   ├── minikube/        # Minikube config
│   └── zsh/             # Zsh specific config
├── dot_local/           # Mapped to ~/.local/
│   └── bin/             # User scripts (added to PATH)
├── dot_zshenv           # The Environment Bootloader
├── dot_psqlrc           # PostgreSQL CLI config
├── dot_sqliterc         # SQLite CLI config
├── .chezmoitemplates/   # Reusable logic blocks
│   ├── aliases/         # Alias definitions by category
│   ├── functions/       # Shell functions
│   └── paths/           # PATH configurations
├── nix/                 # Nix flake for optional toolchain
│   └── flake.nix
├── install/             # Installation scripts
│   ├── helpers/         # Helper scripts
│   └── provision/       # OS-specific provisioning
└── install.sh           # Universal bootstrapping script
```

## Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   chezmoi    │────▶│   templates  │────▶│  target dir  │
│    source    │     │   (.tmpl)    │     │   (~/.*)     │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       │                    ▼                    │
       │             ┌──────────────┐            │
       │             │ .chezmoidata │            │
       │             │   (data)     │            │
       │             └──────────────┘            │
       │                                         │
       └───────────────────┬─────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   hooks      │
                    │  (scripts)   │
                    └──────────────┘
```

## Modern toolchain

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
| `diff` | `delta` | Syntax-highlighted diffs |

## Predictive shell strategy

- **AI Integration**: The shell is "AI Aware" via the `ai_core` wrapper.
- **Autosuggestions**: Context-aware completion based on shell history.
- **Error Analysis**: Hooks to send failed command context to local LLMs or GitHub Copilot for explanation.

## Security posture

- **Hardened Defaults**: Shell scripts run with `set -euo pipefail` to fail fast.
- **Supply Chain Safety**:
  - **Pinned Installation**: Installers reference specific Git tags (e.g., `v0.2.474`), not `main`.
  - **Immutable History**: Logic is version controlled and reviewable via `chezmoi diff`.
- **Audit Logging**: All mutations are logged to `~/.local/share/dotfiles.log`.
- **Encryption**: Sensitive data encrypted with `age`.

## Compatibility

- **macOS**: Full support (Homebrew, defaults).
- **Linux**: Debian/Ubuntu support (apt-get).
- **Windows**: WSL2 support.
