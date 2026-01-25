# Get started

## Overview

This release delivers a modern, universal configuration managed by `chezmoi` across macOS, Linux, and Windows.

## Demo Walkthrough

This guide walks you through the key features of the dotfiles after installation.

### Step 1: Verify Installation

After running the installer, verify everything is working:

```bash
# Check dot CLI is available
dot --version

# Run health checks
dot doctor

# View configuration status
dot status
```

### Step 2: Explore the Shell

The shell is pre-configured with modern tools:

```bash
# Use zoxide for smart directory navigation
z dotfiles          # Jump to ~/.dotfiles
z -                 # Go back

# Use fzf for fuzzy finding
<Ctrl-R>            # Search command history
<Ctrl-T>            # Find files

# Use modern tool replacements
ls                  # Actually runs 'eza'
cat file.txt        # Actually runs 'bat'
```

### Step 3: Git Workflow

Git is configured with helpful aliases:

```bash
# Quick status and log
gst                 # git status
lg                  # pretty git log graph

# Stage and commit
ga .                # git add
gcm "message"       # git commit -m

# Open lazygit TUI
lgui
```

### Step 4: Tmux Basics

If tmux is running:

```bash
# Prefix is Ctrl-a (not Ctrl-b)
<Ctrl-a> c          # New window
<Ctrl-a> |          # Split vertically
<Ctrl-a> -          # Split horizontally
<Ctrl-a> h/j/k/l    # Navigate panes (vim-style)
<Ctrl-a> f          # Fuzzy session switcher
```

### Step 5: Neovim IDE

Open Neovim and explore:

```bash
nvim .

# Inside Neovim:
<Space>             # Leader key, shows command menu
<Space>ff           # Find files
<Space>fg           # Live grep
<Space>e            # Toggle file tree
```

### Step 6: Docker Workflow

Docker aliases for efficiency:

```bash
dps                 # List running containers
dco up -d           # Docker compose up
dlogsf container    # Follow container logs
lzd                 # Open lazydocker TUI
```

### Step 7: Kubernetes (if enabled)

Kubernetes shortcuts:

```bash
k get pods          # kubectl get pods
kctx                # Switch context
kn                  # Switch namespace
k9                  # Open k9s TUI
```

## Core Architecture

- **Chezmoi**: Replaced legacy Makefiles/symlinks with a robust template engine.
- **Universal Templates**: `run_onchange_*.sh.tmpl` scripts adapt to OS (Darwin/Linux) automatically.
- **Performance**: Startup time validated at **~16ms** (Target: <20ms).

## Universal Installer

- **Bootstrap**: `install.sh` enables one-line installation via `curl`.
- **Teleport**: `dot teleport user@host` pushes configs ephemerally to remote servers.
- **Verification**: Syntax checked and validated.

## Deep Integration

- **macOS**: `defaults` hardening (Screensaver, Firewall, Finder).
- **Fonts**: Auto-installation of `JetBrainsMono Nerd Font`.
- **Compliance**: STRICT XDG Base Directory enforcement.

## Self-Healing and Compliance

- **Doctor**: `dot doctor` diagnoses drift, paths, and dependencies.
- **Audit**: All changes logged to `~/.local/share/dotfiles.log`.
- **Privacy**: `privacy-mode` alias disables telemetry.

## Verification

| Test | Status | Notes |
| :--- | :--- | :--- |
| **Syntax** | PASSED | `install.sh`, `pkg.sh`, `teleport.sh` verified. |
| **Performance** | PASSED | **~16ms** Zsh startup time. |
| **Drift** | VARIES | Minor state drift may be reported due to audit logs. |
| **Docker** | PASSED | **Ubuntu 26.04** bootstrap verified (`dotfiles:0.2.472`). |

## Quick Reference Card

| Action | Command |
|--------|---------|
| Update dotfiles | `dot update` |
| Check health | `dot doctor` |
| Show drift | `dot drift` |
| Apply changes | `dot apply` |
| Edit source | `dot edit` |
| Benchmark shell | `dot benchmark` |
| New project | `dot new python myapp` |
| Enter sandbox | `dot sandbox` |

## Video Tutorial

A video walkthrough is planned for a future release. In the meantime, refer to this document and the individual tool documentation for guidance.

## Next Steps

- Customize your shell prompt in `~/.config/starship.toml`
- Add custom aliases in `~/.dotfiles/.chezmoitemplates/aliases/`
- Configure Neovim plugins in `~/.config/nvim/`
- Set up secrets with `dot secrets-init`
