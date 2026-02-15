# Configuration Management Strategy

## Overview

This document defines the configuration management approach for this development environment, consolidating multiple systems into a clear hierarchy.

## Configuration Systems

### Primary: Chezmoi

**Role:** Source of truth for all managed dotfiles
**Location:** `~/.dotfiles/` (chezmoi source directory)
**Managed Files:** See `chezmoi managed`

Chezmoi handles:
- Shell configurations (.bashrc, .zshrc, .profile, .zshenv, .zprofile)
- Editor configs (.vimrc, nvim, VS Code settings)
- Tool configs (.gitconfig, .npmrc, .noderc, etc.)
- Application configs (~/.config/*)
- SSH configuration (~/.ssh/config, config.d/)

### Secondary: Euxis

**Role:** AI agent orchestration framework (self-contained)
**Location:** `~/.euxis/`
**Management:** Git-tracked, symlinked from `~/Code/Private/euxis`

Euxis is intentionally separate from chezmoi because:
- It has its own versioning and release cycle
- It contains runtime data (sessions, memory)
- It may be shared across machines differently than dotfiles

### Tertiary: Runtime/Application Data

**Role:** Auto-generated, not version controlled
**Examples:**
- `~/.cache/` - Application caches
- `~/.local/share/` - Application data
- `~/.cargo/`, `~/.rustup/` - Language toolchains
- `~/.npm/`, `~/.node_modules/` - Node.js packages

## Decision Matrix

| Configuration Type | Manager | Reason |
|-------------------|---------|--------|
| Shell dotfiles | Chezmoi | Templated, machine-specific |
| Editor configs | Chezmoi | Consistent across machines |
| Git config | Chezmoi | Templated (email, signing key) |
| SSH config | Chezmoi | Structured with config.d/ |
| Euxis framework | Git (separate) | Independent lifecycle |
| Language runtimes | mise | Version management |
| System packages | apt/snap | OS-level |
| Application data | None | Auto-generated |

## Chezmoi Configuration

### Data Variables (.chezmoidata.toml)

```toml
profile = "laptop"           # Machine profile
theme = "catppuccin-mocha"   # Color scheme
terminal_font_family = "JetBrains Mono"
terminal_font_size = 12

[features]
zsh = true      # Enable zsh configs
nvim = true     # Enable neovim configs
tmux = true     # Enable tmux configs
gui = true      # Enable GUI app configs
secrets = true  # Enable secret management
```

### Template Patterns

Files ending in `.tmpl` are processed with Go templates:
- `dot_gitconfig.tmpl` - Injects name, email, signing key
- `dot_npmrc.tmpl` - Injects registry tokens
- `dot_noderc.tmpl` - Injects Node.js settings

### Ignored Patterns (.chezmoiignore.tmpl)

Machine-specific exclusions based on profile and features.

## Workflow

### Adding New Configuration

1. **Check if managed:** `chezmoi managed | grep <file>`
2. **If not managed:** `chezmoi add <file>`
3. **If templating needed:** Rename to `.tmpl`, add template logic
4. **Apply changes:** `chezmoi apply`

### Updating Configuration

1. **Edit source:** `chezmoi edit <file>` or edit in `~/.dotfiles/`
2. **Preview changes:** `chezmoi diff`
3. **Apply:** `chezmoi apply`
4. **Commit:** `cd ~/.dotfiles && git add -A && git commit`

### Syncing Across Machines

```bash
# On new machine
chezmoi init https://github.com/sebastienrousseau/dotfiles.git
chezmoi apply

# On existing machine
chezmoi update
```

## Anti-Patterns to Avoid

1. **Manual edits to managed files** - Always edit via chezmoi or re-add after manual changes
2. **Duplicate configs** - Don't maintain parallel configs outside chezmoi
3. **Hardcoded machine-specific values** - Use templates and data variables
4. **Version controlling runtime data** - Keep ~/.cache, ~/.local/share out of version control

## File Ownership

| Path | Owner | Notes |
|------|-------|-------|
| `~/.dotfiles/` | chezmoi | Source of truth |
| `~/.euxis/` | Git (Code/Private) | Symlinked |
| `~/.*` (dotfiles) | chezmoi-applied | Don't edit directly |
| `~/.config/*` | Mixed | Check `chezmoi managed` |
| `~/.local/` | chezmoi (bin) + runtime | Partial management |

## Maintenance Schedule

- **Weekly:** `chezmoi update` to sync remote changes
- **Monthly:** Review `chezmoi unmanaged` for new configs to add
- **Quarterly:** Audit `.chezmoiignore` patterns
