# Dotfiles Documentation

<div align="center">

**A modern, cross-platform shell environment built for developers.**

[Quick Start](#quick-start) · [Features](#features) · [Architecture](#architecture) · [Security](#security) · [Contributing](#contributing)

</div>

---

## Overview

Welcome to the dotfiles documentation. This guide will help you install, configure, and customize your development environment across macOS, Linux, and WSL.

### What You'll Get

| Feature | Description |
|---------|-------------|
| 🚀 **Fast Shell** | Zsh with lazy loading, <500ms startup |
| 🔧 **Modern Tools** | Neovim, tmux, starship, fzf, ripgrep |
| 🔐 **Security First** | Encrypted secrets, credential management |
| 🎨 **Beautiful UI** | Nerd Fonts, themes, consistent styling |
| 📦 **Cross-Platform** | macOS, Linux, WSL2 support |

---

## Table of Contents

### Getting Started
- [Installation Guide](INSTALL.md) — Set up your environment in minutes
- [Walkthrough](WALKTHROUGH.md) — Interactive tour of key features
- [Features Overview](FEATURES.md) — Complete feature list

### Core Documentation
- [Architecture](ARCHITECTURE.md) — System design and structure
- [Operations Guide](OPERATIONS.md) — Daily usage and maintenance
- [Troubleshooting](TROUBLESHOOTING.md) — Common issues and solutions

### Configuration
- [Aliases Reference](ALIASES.md) — Shell aliases and shortcuts
- [Keybindings](KEYS.md) — Keyboard shortcuts catalog
- [Tools Reference](TOOLS.md) — Installed tools and utilities
- [Utilities](UTILS.md) — Helper scripts and functions

### Customization
- [Fonts Guide](FONTS.md) — Nerd Fonts installation
- [Screenshots](SCREENSHOTS.md) — Visual gallery
- [Neovim IDE Guide](NEOVIM_IDE_GUIDE.md) — Editor configuration

### Security
- [Security Overview](SECURITY.md) — Security model and practices
- [Security Checklist](SECURITY_CHECKLIST.md) — Hardening guide
- [Secrets Management](SECRETS.md) — Encrypted credentials

### Development
- [Testing Guide](TESTING.md) — Test framework and coverage
- [Compliance](COMPLIANCE.md) — Standards and policies
- [Architecture Decisions](adr/) — ADRs for key decisions

### Platform-Specific
- [WSL2 + Nix Guide](WSL2_NIX_TROUBLESHOOTING.md) — Windows Subsystem for Linux

### Reference
- [Roadmap](ROADMAP.md) — Future plans and priorities
- [Legacy Roadmap](LEGACY_ROADMAP.md) — Historical context
- [2026 Hardening Backlog](BACKLOG_2026_HARDENING.md) — Prioritized implementation plan

---

## Quick Start

### Prerequisites

- macOS 12+, Ubuntu 22.04+, or Windows 11 with WSL2
- Git 2.30+
- curl or wget

### Installation

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh | bash
```

Or clone and install manually:

```bash
git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

### First Steps

After installation, run these commands to explore:

```bash
dot help          # Show all available commands
dot doctor        # Check system health
dot learn         # Interactive tour
dot keys          # View keybindings
```

---

## Features

### Shell Environment

The shell configuration provides a fast, feature-rich experience:

```
┌─────────────────────────────────────────────────────────────┐
│  Startup Time: <500ms  │  Plugin Manager: Zinit            │
│  Prompt: Starship      │  Completions: Lazy-loaded         │
│  History: Shared       │  Syntax: fast-syntax-highlighting │
└─────────────────────────────────────────────────────────────┘
```

**Key Features:**
- Intelligent command suggestions with autosuggestions
- Fuzzy finding with fzf for files, history, and git
- Git integration with delta for beautiful diffs
- Directory jumping with zoxide

### Development Tools

Pre-configured toolchains for modern development:

| Language | Tools |
|----------|-------|
| **Rust** | rustup, cargo, clippy, rustfmt |
| **Go** | go, golangci-lint |
| **Node.js** | nvm, npm, pnpm |
| **Python** | pyenv, pipx, uv |

### AI Integration

Built-in support for AI coding assistants:

- **aider** — AI pair programming
- **Claude** — Anthropic's assistant
- **GitHub Copilot** — Code suggestions
- **git-ai-commit** — AI-powered commit messages

---

## Architecture

The dotfiles follow a modular architecture:

```
~/.dotfiles/
├── dot_config/           # XDG config files
│   ├── nvim/             # Neovim configuration
│   ├── zsh/              # Zsh configuration layers
│   └── git/              # Git configuration
├── dot_local/bin/        # User scripts and tools
├── install/              # Installation scripts
│   └── provision/        # Tool provisioning
├── scripts/              # Operational scripts
│   ├── dot/commands/     # CLI command modules
│   ├── diagnostics/      # Health checks
│   ├── security/         # Security tools
│   └── tuning/           # Performance tuning
└── docs/                 # Documentation (you are here)
```

### Shell Layer System

Zsh configuration uses numbered layers for predictable loading:

| Range | Purpose | Examples |
|-------|---------|----------|
| 00-19 | Core | Environment, history, options |
| 20-49 | Middleware | Zinit, completions, plugins |
| 50-89 | Toolchain | Languages, package managers |
| 90-99 | UX | Prompt, aliases, keybindings |

### CLI Architecture

The `dot` CLI uses modular command dispatch:

```bash
dot <command> [args]
     │
     ├── core.sh        # apply, sync, update, diff
     ├── diagnostics.sh # doctor, heal, benchmark
     ├── tools.sh       # tools, new, packages
     ├── appearance.sh  # theme, fonts, wallpaper
     ├── secrets.sh     # secrets-init, secrets
     ├── security.sh    # firewall, backup, encrypt
     └── meta.sh        # upgrade, docs, learn
```

---

## Security

Security is a core principle, not an afterthought.

### Secrets Management

```bash
dot secrets-init    # Initialize age encryption
dot secrets         # Edit encrypted secrets
dot ssh-key         # Encrypt SSH keys
```

Secrets are encrypted with [age](https://age-encryption.org/) and never stored in plaintext.

### Credential Management

Supported credential stores:
- **macOS** — Keychain integration
- **Linux** — libsecret / GNOME Keyring
- **Git** — git-credential-manager

### Security Hardening (Opt-in)

```bash
dot firewall      # Configure firewall rules
dot telemetry     # Disable OS telemetry
dot dns-doh       # Enable DNS-over-HTTPS
dot encrypt-check # Verify disk encryption
```

All security modifications require explicit consent.

---

## Contributing

We welcome contributions! Please see our guidelines:

1. **Fork** the repository
2. **Create** a feature branch
3. **Test** your changes with `dot doctor`
4. **Submit** a pull request

### Code Style

- Shell scripts: Follow ShellCheck recommendations
- Templates: Use `.chezmoitemplates/` for reusable logic
- Documentation: Use UPPERCASE.md naming convention

### Testing

```bash
./scripts/tests/framework/test_runner.sh        # Unit tests
RUN_INTEGRATION=1 ./scripts/tests/framework/test_runner.sh  # Integration
```

---

## Support

- **Issues**: [GitHub Issues](https://github.com/sebastienrousseau/dotfiles/issues)
- **Discussions**: [GitHub Discussions](https://github.com/sebastienrousseau/dotfiles/discussions)

---

<div align="center">

**[Back to Top](#dotfiles-documentation)**

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)

</div>
