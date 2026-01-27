# How it works

v0.2.475 constitutes a portable **shell distribution** that `chezmoi` manages. This document outlines the core architectural decisions and system design.

## Core philosophy

- **XDG-first**: Configuration strictly maps to `~/.config/` (XDG Base Directory specification). This approach avoids `~/.foo` file sprawl in the home directory.
- **Single entrypoint**: `dot_zshenv` acts as the bootloader. Zsh loads it immediately and sets up the environment (XDG variables, PATH) before any other initialization runs.
- **Zero-dependency bootstrap**: The installation process relies only on `curl` and `git` (and `chezmoi`, which the installer fetches automatically).

## Architecture diagram

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

The repository follows standard `chezmoi` conventions.

```text
~/.dotfiles/
├── dot_config/          # Maps to ~/.config/
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
│   └── zsh/             # Zsh-specific config
├── dot_local/           # Maps to ~/.local/
│   └── bin/             # Scripts added to PATH
├── dot_zshenv           # The environment bootloader
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

## Data flow

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

Dotfiles replaces legacy Unix tools with high-performance Rust alternatives:

| Legacy | Modern replacement | Purpose |
| :--- | :--- | :--- |
| `ls` | `eza` | Modern file listing with git integration |
| `cat` | `bat` | Syntax highlighted file viewing |
| `grep` | `ripgrep` (`rg`) | High-performance search |
| `cd` | `zoxide` | Smart directory jumping |
| `history` | `atuin` | Syncable, encrypted SQLite history |
| `find` | `fd` | Developer-friendly filesystem search |
| `vim` | `neovim` | Lua-extensible IDE |
| `diff` | `delta` | Syntax-highlighted diffs |

## Predictive shell strategy

- **AI integration**: The shell integrates AI features through the `ai_core` wrapper.
- **Autosuggestions**: Context-aware completion based on shell history.
- **Error analysis**: Hooks send failed command context to local LLMs or GitHub Copilot for explanation.

## Security posture

- **Hardened defaults**: Shell scripts run with `set -euo pipefail` to fail fast.
- **Supply chain safety**:
  - **Pinned installation**: Installers reference specific Git tags (for example, `v0.2.475`), not `main`.
  - **Immutable history**: All logic stays version-controlled and reviewable through `chezmoi diff`.
- **Audit logging**: Dotfiles logs all mutations to `~/.local/share/dotfiles.log`.
- **Encryption**: `age` encrypts all sensitive data.

## Compatibility

- **macOS**: Full support (Homebrew, defaults).
- **Linux**: Debian/Ubuntu support (apt-get).
- **Windows**: WSL2 support.
