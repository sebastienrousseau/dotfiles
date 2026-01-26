# Get started

## Overview

This release provides a modern, universal configuration that `chezmoi` manages across macOS, Linux, and Windows.

## Demo walkthrough

This guide walks you through the key features of the dotfiles after installation.

### Step 1: Verify installation

After running the installer, verify that everything works:

```bash
# Check dot CLI is available
dot --version

# Run health checks
dot doctor

# View configuration status
dot status
```

### Step 2: Explore the shell

Your shell comes pre-configured with modern tools:

```bash
# Use zoxide for smart directory navigation
z dotfiles          # Jump to ~/.dotfiles
z -                 # Go back

# Use fzf for fuzzy finding
<Ctrl-R>            # Search command history
<Ctrl-T>            # Find files

# Use modern tool replacements
ls                  # Runs 'eza'
cat file.txt        # Runs 'bat'
```

### Step 3: Git workflow

Git includes helpful aliases:

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

### Step 4: Tmux basics

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

Open Neovim:

```bash
nvim .

# Inside Neovim:
<Space>             # Leader key, shows command menu
<Space>ff           # Find files
<Space>fg           # Live grep
<Space>e            # Toggle file tree
```

### Step 6: Docker workflow

Docker aliases:

```bash
dps                 # List running containers
dco up -d           # Docker compose up
dlogsf container    # Follow container logs
lzd                 # Open lazydocker TUI
```

### Step 7: Kubernetes (if enabled)

Kubernetes aliases:

```bash
k get pods          # kubectl get pods
kctx                # Switch context
kn                  # Switch namespace
k9                  # Open k9s TUI
```

## Core architecture

- **Chezmoi**: Replaces legacy Makefiles and symlinks with a robust template engine.
- **Universal templates**: `run_onchange_*.sh.tmpl` scripts adapt to OS (Darwin/Linux) automatically.
- **Performance**: Startup time benchmarks at **~16ms** (target: <20ms).

## Universal installer

- **Bootstrap**: `install.sh` enables one-line installation through `curl`.
- **Teleport**: `dot teleport user@host` pushes configs ephemerally to remote servers.
- **Verification**: All syntax checks pass.

## Deep integration

- **macOS**: `defaults` hardening (screensaver, firewall, Finder).
- **Fonts**: Auto-installation of `JetBrainsMono Nerd Font`.
- **Compliance**: Strict XDG Base Directory enforcement.

## Self-healing and compliance

- **Doctor**: `dot doctor` diagnoses drift, paths, and dependencies.
- **Audit**: Dotfiles logs all changes to `~/.local/share/dotfiles.log`.
- **Privacy**: The `privacy-mode` alias disables telemetry.

## Verification

| Test | Status | Notes |
| :--- | :--- | :--- |
| **Syntax** | PASSED | `install.sh`, `pkg.sh`, `teleport.sh` verified. |
| **Performance** | PASSED | **~16ms** Zsh startup time. |
| **Drift** | VARIES | Audit logs may cause minor state drift reports. |
| **Docker** | PASSED | **Ubuntu 26.04** bootstrap verified (`dotfiles:0.2.474`). |

## Quick reference card

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

## Video tutorial

A future release will include a video walkthrough. Until then, use this document and the individual tool documentation.

## Next steps

- Customize your shell prompt in `~/.config/starship.toml`
- Add custom aliases in `~/.dotfiles/.chezmoitemplates/aliases/`
- Configure Neovim plugins in `~/.config/nvim/`
- Set up secrets with `dot secrets-init`
