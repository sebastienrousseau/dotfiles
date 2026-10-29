# Configuration Management Strategy

## Overview

This document defines the configuration management approach for this development environment, consolidating multiple systems into a clear hierarchy.

## Configuration Systems

### Primary: Chezmoi

**Role:** Source of truth for all managed dotfiles
**Location:** `~/.dotfiles/` (the repo; `.chezmoiroot` makes `~/.dotfiles/defaults/` the chezmoi source directory)
**Managed Files:** run `chezmoi managed` for the current list

Chezmoi handles:

- Shell configurations (.bashrc, .zshrc, .profile, .zshenv, .zprofile)
- Editor configs (.vimrc, nvim, VS Code settings)
- Tool configs (.gitconfig, .npmrc, .noderc, etc.)
- Application configs (~/.config/*)
- SSH configuration (~/.ssh/config, config.d/)


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

### Data Variables (defaults/.chezmoidata.toml)

An excerpt; see [FEATURES.md](reference/FEATURES.md) for every flag:

```toml
profile = "laptop"           # Machine profile
theme = "maui-dark"          # Resolved palette (theme_family + theme_mode pick it at runtime)
theme_family = "maui"
theme_mode = "auto"
terminal_font_family = "JetBrainsMono Nerd Font"
terminal_font_size = 20
default_shell = "fish"

[features]
zellij = false         # Zellij multiplexer config
linux_desktop = false  # Linux desktop / Wayland configs
ai_theme_sync = true   # Wallpaper-aware AI CLI appearance
```

### Template Patterns

Files ending in `.tmpl` are processed with Go templates, and so is a `modify_` script that starts with `chezmoi:modify-template`:

- `defaults/dot_gitconfig.tmpl` - Injects name, email, signing key
- `defaults/modify_private_dot_npmrc` - Injects registry tokens and keeps the auth lines `npm login` writes

### Ignored Patterns (defaults/.chezmoiignore.tmpl)

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
chezmoi init https://github.com/<user>/dotfiles.git
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
| `~/.*` (dotfiles) | chezmoi-applied | Don't edit directly |
| `~/.config/*` | Mixed | Check `chezmoi managed` |
| `~/.local/` | chezmoi (bin) + runtime | Partial management |

## Maintenance Schedule

- **Weekly:** `chezmoi update` to sync remote changes
- **Monthly:** Review `chezmoi unmanaged` for new configs to add
- **Quarterly:** Audit `.chezmoiignore` patterns
