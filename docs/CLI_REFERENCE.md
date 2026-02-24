# Dot CLI Reference

Complete reference for all `dot` commands with examples, options, and exit codes.

## Quick Reference

| Category | Commands |
|----------|----------|
| **Core** | `apply`, `sync`, `update`, `diff`, `status`, `add`, `remove`, `edit` |
| **Setup** | `setup`, `doctor`, `heal`, `learn`, `suggest` |
| **Tools** | `tools`, `new`, `packages`, `devcontainer` |
| **Appearance** | `theme`, `fonts`, `wallpaper` |
| **Security** | `secrets`, `secrets-init`, `ssh-key`, `backup`, `firewall` |
| **Meta** | `help`, `version`, `upgrade`, `docs` |

---

## Core Commands

### `dot apply`

Apply dotfiles configuration using chezmoi.

```bash
dot apply [--force] [--dry-run]
```

**Options:**
- `--force`, `-f`: Skip confirmation prompts
- `--dry-run`, `-n`: Show what would change without applying

**Exit Codes:**
- `0`: Success
- `1`: Error during apply

**Examples:**
```bash
dot apply              # Apply with confirmation
dot apply --force      # Apply without prompts
dot apply --dry-run    # Preview changes
```

---

### `dot sync`

Alias for `dot apply`. Synchronize local configuration with dotfiles source.

---

### `dot update`

Pull latest changes from remote and apply.

```bash
dot update [--no-apply]
```

**Options:**
- `--no-apply`: Pull changes but don't apply

**Examples:**
```bash
dot update             # Pull and apply
dot update --no-apply  # Pull only
```

---

### `dot diff`

Show pending changes between source and deployed files.

```bash
dot diff [FILE...]
```

**Examples:**
```bash
dot diff                    # Show all pending changes
dot diff ~/.zshrc           # Show changes for specific file
```

---

### `dot status`

Show configuration drift status.

```bash
dot status [--json]
```

**Options:**
- `--json`: Output as JSON for scripting

---

### `dot add`

Add a file to dotfiles management.

```bash
dot add <FILE> [--template]
```

**Options:**
- `--template`, `-t`: Add as a template file (.tmpl)

**Examples:**
```bash
dot add ~/.config/app/config.toml
dot add ~/.gitconfig --template
```

---

### `dot remove`

Remove a file from dotfiles management.

```bash
dot remove <FILE>
```

---

### `dot edit`

Open dotfiles source directory in editor.

```bash
dot edit [FILE]
```

**Examples:**
```bash
dot edit                  # Open source directory
dot edit ~/.zshrc         # Edit specific file's source
```

---

## Setup Commands

### `dot setup`

Interactive setup wizard for initial configuration.

```bash
dot setup [--quick]
```

**Options:**
- `--quick`, `-q`: Use defaults, minimal prompts

**Configures:**
- Profile selection
- Git identity
- Feature toggles
- Theme selection

---

### `dot doctor`

Run system health checks and diagnostics.

```bash
dot doctor [--json] [--fix]
```

**Options:**
- `--json`: Output as JSON
- `--fix`: Attempt automatic fixes

**Checks:**
- Required dependencies
- Shell configuration
- Git setup
- Tool availability
- File permissions

**Exit Codes:**
- `0`: All checks passed
- `1`: One or more checks failed

---

### `dot heal`

Automatically fix common issues found by `dot doctor`.

```bash
dot heal [--dry-run]
```

---

### `dot learn`

Start interactive tour of dotfiles features.

```bash
dot learn
```

---

### `dot suggest`

AI-powered suggestions for dotfiles optimization.

```bash
dot suggest [CATEGORY]
```

**Categories:**
- `aliases`: Suggest aliases for frequent commands
- `tools`: Suggest modern tool replacements
- `config`: Check configuration for issues
- `profile`: Recommend optimal profile
- `ai`: AI-enhanced suggestions (requires Claude/Copilot)
- `all`: Run all suggestion categories (default)

**Examples:**
```bash
dot suggest              # Run all suggestions
dot suggest aliases      # Only alias suggestions
dot suggest tools        # Only tool suggestions
```

---

### `dot drift`

Smart drift detection with automatic remediation.

```bash
dot drift [COMMAND] [OPTIONS]
```

**Commands:**
- `check`: Analyze drift and show summary (default)
- `report`: Detailed report with remediation suggestions
- `fix`: Apply fixes to drifted files
- `watch`: Continuous monitoring mode

**Options for 'report':**
- `--critical`: Only show critical (security) files
- `--warning`: Only show warning (shell config) files
- `--safe`: Only show safe (low-risk) files

**Options for 'fix':**
- `--safe`: Only fix auto-safe changes
- `--all`: Fix all except critical files
- `--force`: Fix everything (use with caution!)

**Severity Levels:**
- Critical: Security files (.ssh, .gnupg, secrets)
- Warning: Shell configuration (.zshrc, .bashrc)
- Info: General configuration files
- Safe: Editor/tool configs (auto-fixable)

**Examples:**
```bash
dot drift                    # Check for drift
dot drift report             # Full report with suggestions
dot drift report --critical  # Only security-sensitive files
dot drift fix --safe         # Auto-fix safe changes only
dot drift watch              # Continuous monitoring
```

---

## Tools Commands

### `dot tools`

Browse and manage development tools.

```bash
dot tools [list|install|docs] [TOOL]
```

**Subcommands:**
- `list`: Show available tools
- `install <tool>`: Install a tool
- `docs <tool>`: Show tool documentation

**Examples:**
```bash
dot tools list           # List all tools
dot tools install nvim   # Install Neovim
dot tools docs fzf       # Show fzf documentation
```

---

### `dot new`

Create a new project from templates.

```bash
dot new <LANGUAGE> <NAME>
```

**Supported Languages:**
- `rust`, `go`, `python`, `node`, `typescript`

**Examples:**
```bash
dot new rust my-project
dot new python api-server
```

---

### `dot packages`

Show installed package managers and statistics.

```bash
dot packages [--json]
```

---

### `dot devcontainer`

Generate devcontainer configuration.

```bash
dot devcontainer [--init|--codespaces|--gitpod] [DIR]
```

**Options:**
- `--init`: Generate for VS Code (default)
- `--codespaces`: Optimize for GitHub Codespaces
- `--gitpod`: Generate .gitpod.yml
- `--image IMAGE`: Specify base image
- `--repo URL`: Dotfiles repository URL

**Examples:**
```bash
dot devcontainer                    # Create .devcontainer/
dot devcontainer --codespaces       # For Codespaces
dot devcontainer --gitpod           # Create .gitpod.yml
```

---

## Appearance Commands

### `dot theme`

Switch color theme across terminal and tools.

```bash
dot theme [THEME]
```

**Available Themes:**
- `catppuccin-mocha`, `catppuccin-latte`
- `tokyonight-night`, `tokyonight-day`
- `gruvbox-dark`, `nord`

**Examples:**
```bash
dot theme                        # Interactive selection
dot theme catppuccin-mocha       # Set specific theme
```

---

### `dot fonts`

Install Nerd Fonts.

```bash
dot fonts [FONT]
```

**Examples:**
```bash
dot fonts                  # Install default fonts
dot fonts JetBrainsMono    # Install specific font
```

---

### `dot wallpaper`

Set desktop wallpaper (GUI environments).

```bash
dot wallpaper [IMAGE]
```

---

## Security Commands

### `dot secrets-init`

Initialize age encryption for secrets.

```bash
dot secrets-init [--force]
```

Creates `~/.config/chezmoi/key.txt` for secret encryption.

---

### `dot secrets`

Edit encrypted secrets file.

```bash
dot secrets [edit|list|add|remove]
```

---

### `dot ssh-key`

Manage SSH key encryption.

```bash
dot ssh-key [encrypt|decrypt]
```

---

### `dot backup`

Create compressed backup of home directory.

```bash
dot backup [--exclude PATTERN] [OUTPUT]
```

**Examples:**
```bash
dot backup                              # Backup to ~/backup-TIMESTAMP.tar.gz
dot backup --exclude node_modules ~/backup.tar.gz
```

---

### `dot firewall`

Apply firewall hardening rules.

```bash
dot firewall [enable|disable|status]
```

**Requires:** Elevated privileges (sudo)

---

## Meta Commands

### `dot help`

Show help information.

```bash
dot help [COMMAND]
```

**Examples:**
```bash
dot help            # Show all commands
dot help theme      # Show theme command help
```

---

### `dot version`

Show dotfiles version.

```bash
dot version [--short]
```

---

### `dot upgrade`

Update dotfiles, plugins, and tools.

```bash
dot upgrade [--all]
```

**Upgrades:**
- Dotfiles repository
- Zinit plugins
- Neovim plugins
- Tool versions

---

### `dot docs`

Open documentation in browser.

```bash
dot docs [TOPIC]
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOTFILES_PROFILE` | `laptop` | Active profile (minimal/laptop/workstation/server/work) |
| `DOTFILES_FAST` | `0` | Enable fast startup mode |
| `DOTFILES_ULTRA_FAST` | `0` | Enable minimal startup mode |
| `DOTFILES_NONINTERACTIVE` | `0` | Disable prompts for CI/scripts |
| `DOTFILES_THEME` | `catppuccin-mocha` | Color theme |
| `CHEZMOI_SOURCE_DIR` | `~/.dotfiles` | Dotfiles source directory |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Invalid arguments |
| `126` | Permission denied |
| `127` | Command not found |

---

## Shell Integration

### Completions

Completions are installed automatically for:
- Zsh: `~/.local/share/zsh/completions/_dot`
- Bash: `~/.local/share/bash-completion/completions/dot`

### Aliases

Common aliases defined in shell configuration:
- `d` → `dot`
- `ds` → `dot status`
- `da` → `dot apply`
- `du` → `dot update`

---

## See Also

- [Installation Guide](INSTALL.md)
- [Operations Guide](OPERATIONS.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Architecture](ARCHITECTURE.md)
