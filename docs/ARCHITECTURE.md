# How it works

v0.2.485 constitutes a portable **shell distribution** that `chezmoi` manages. This document outlines the core architectural decisions and system design.

## Core philosophy

- **XDG-first**: Configuration strictly maps to `~/.config/` (XDG Base Directory specification). This approach avoids `~/.foo` file sprawl in the home directory.
- **Single entrypoint**: `dot_zshenv` acts as the bootloader. Zsh loads it immediately and sets up the environment (XDG variables, PATH) before any other initialization runs.
- **Zero-dependency bootstrap**: The installation process relies only on `curl` and `git` (and `chezmoi`, which the installer fetches automatically).
- **Lazy-by-default**: Heavy tooling (fnm, nvm, SDKMAN, tool-specific aliases) is deferred until first use or after the first prompt to keep shell startup fast.

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

## Shell startup flow

Zsh loads files in a specific order. Dotfiles uses this to layer configuration predictably.

```
dot_zshenv                          # Phase 0: XDG vars, essential PATH (~/.local/bin, Homebrew)
  └─▶ dot_config/zsh/dot_zshrc     # Phase 1: Main orchestrator
        ├─▶ rc.d/10-env.zsh        # Phase 2: Environment variables
        ├─▶ rc.d/20-zinit.zsh      # Phase 3: Plugin manager (Zinit)
        ├─▶ rc.d/30-options.zsh    # Phase 4: History, keybindings, lazy-loaders (fnm, nvm, SDKMAN)
        ├─▶ rc.d/40-plugins.zsh    # Phase 5: Zinit plugins
        ├─▶ rc.d/50-vi-mode.zsh   # Phase 6: Vi-mode configuration
        │
        ├─▶ shell/00-core-paths    # Phase 7: Full PATH construction
        ├─▶ shell/05-core-safety   # Phase 8: Safety defaults (umask, etc.)
        ├─▶ shell/40-ls-colors     # Phase 9: LS_COLORS
        ├─▶ shell/50-logic-funcs   # Phase 10: Shell functions (60+)
        ├─▶ shell/90-ux-aliases    # Phase 11: Core aliases (eager, ~40KB)
        │
        ├─▶ [precmd hook]          # Phase 12: Lazy-load tool aliases (~137KB, after first prompt)
        │     └─▶ shell/91-ux-aliases-lazy
        │
        ├─▶ atuin init             # Phase 13: Shell history
        ├─▶ starship init          # Phase 14: Prompt
        ├─▶ zoxide init            # Phase 15: Smart cd
        └─▶ fzf init               # Phase 16: Fuzzy finder
```

### rc.d load order

Files under `~/.config/zsh/rc.d/` are sourced in **glob order** (alphabetical by filename). The numeric prefix controls execution order:

| Range | Purpose | Examples |
|-------|---------|---------|
| `10-*` | Environment variables, exports | `10-env.zsh` |
| `20-*` | Plugin manager bootstrap | `20-zinit.zsh` |
| `30-*` | Shell options, lazy-loaders | `30-options.zsh` |
| `40-*` | Plugin declarations | `40-plugins.zsh` |
| `50-*` | Input mode (vi-mode) | `50-vi-mode.zsh` |

### shell/ load order

Files under `~/.config/shell/` are sourced explicitly by `dot_zshrc` in lexical order:

| Range | Purpose | Examples |
|-------|---------|---------|
| `00-19` | Core: PATH, safety | `00-core-paths.sh`, `05-core-safety.sh` |
| `40-49` | Middleware: colors, exports | `40-ls-colors.sh` |
| `50-89` | Toolchain: functions | `50-logic-functions.sh` |
| `90-99` | UX: aliases, prompts | `90-ux-aliases.sh` (eager), `91-ux-aliases-lazy.sh` (deferred) |

### Alias system

Aliases are defined in `.chezmoitemplates/aliases/` with one directory per category:

```text
.chezmoitemplates/aliases/
├── cd/cd.aliases.sh             # Directory navigation
├── git/git.aliases.sh           # Git shortcuts
├── docker/docker.aliases.sh     # Container management
├── kubernetes/kubernetes.aliases.sh
├── python/python.aliases.sh
├── rust/rust.aliases.sh
└── ... (50+ categories, each with README.md)
```

At `chezmoi apply` time, Chezmoi's `glob` function discovers all `*.aliases.sh` files and aggregates them into two output files:

- **`90-ux-aliases.sh`** — 14 core categories (cd, git, editor, sudo, etc.) loaded eagerly at startup.
- **`91-ux-aliases-lazy.sh`** — 35+ tool-specific categories (docker, kubernetes, terraform, etc.) loaded after the first prompt via a `precmd` hook.

**Ordering convention:** Templates are included in **alphabetical order** by their file path. This is implicit — renaming a file changes its load position. At current scale (~50 categories) this is acceptable; if the count exceeds ~100, consider introducing an explicit manifest.

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
  - **Pinned installation**: Installers reference specific Git tags (for example, `v0.2.485`), not `main`.
  - **Immutable history**: All logic stays version-controlled and reviewable through `chezmoi diff`.
- **Audit logging**: Dotfiles logs all mutations to `~/.local/share/dotfiles.log`.
- **Encryption**: `age` encrypts all sensitive data.

## Compatibility

- **macOS**: Full support (Homebrew, defaults).
- **Linux**: Debian/Ubuntu support (apt-get).
- **Windows**: WSL2 support.
