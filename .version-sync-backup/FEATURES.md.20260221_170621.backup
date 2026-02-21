# Feature Flags

Feature flags control which components and configurations are enabled in your dotfiles setup. They are defined in `.chezmoidata.toml` and used throughout template files to conditionally include or exclude functionality.

## Configuration

Feature flags are configured in the `.chezmoidata.toml` file:

```toml
[features]
zsh = true
nvim = true
tmux = true
gui = true
secrets = true
```

## Available Feature Flags

| Flag | Default | Purpose | Dependencies | Impact |
|------|---------|---------|--------------|---------|
| `zsh` | `true` | Enable Zsh shell configuration and optimizations | - | Controls Zsh-specific configs, aliases, and shell enhancements |
| `nvim` | `true` | Enable Neovim editor configuration | - | Manages Neovim configs, plugins, and editor-specific settings |
| `tmux` | `true` | Enable tmux terminal multiplexer configuration | - | Controls tmux configs, key bindings, and session management |
| `gui` | `true` | Enable GUI application configurations | Desktop environment | Manages GUI app configs, window managers, and desktop settings |
| `secrets` | `true` | Enable secrets management and encryption tools | GPG, Age, SSH keys | Controls access to encrypted configs and secure credential storage |

## How Feature Flags Work

### Template Processing

Feature flags are processed in the Zsh configuration template (`dot_config/zsh/dot_zshrc.tmpl`) where they:

1. **Set defaults**: If not explicitly defined, all features default to `true`
2. **Export environment variables**: Active features are exported as `DOTFILES_FEATURES`
3. **Enable conditional loading**: Allow selective inclusion of shell configurations

### Example Usage

```bash
# In template files, feature flags are referenced as:
{{- $features := default (dict "zsh" true "nvim" true "tmux" true "gui" true "secrets" true) .features -}}

# Export enabled features to environment
export DOTFILES_FEATURES="{{ join "," $enabled }}"
```

### Runtime Access

Once processed, you can check active features in your shell:

```bash
# View all enabled features
echo $DOTFILES_FEATURES

# Check if a specific feature is enabled
if [[ "$DOTFILES_FEATURES" == *"nvim"* ]]; then
    echo "Neovim configuration is active"
fi
```

## Modifying Feature Flags

### Enable/Disable Features

Edit `.chezmoidata.toml`:

```toml
[features]
zsh = true
nvim = true
tmux = false    # Disable tmux configuration
gui = false     # Disable GUI configurations
secrets = true
```

### Apply Changes

After modifying feature flags, apply the changes:

```bash
chezmoi apply
```

### Profile-Specific Overrides

For machine-specific configurations, you can override feature flags in your local chezmoi config (`~/.config/chezmoi/chezmoi.toml`):

```toml
[data.features]
gui = false  # Override: disable GUI on this machine
```

## Feature Flag Dependencies

### Core Dependencies

- **zsh**: Core shell functionality - recommended to keep enabled
- **nvim**: Independent - can be disabled if using alternative editors
- **tmux**: Independent - can be disabled if not using terminal multiplexer

### Conditional Dependencies

- **gui**: Requires desktop environment; automatically ignored on headless systems
- **secrets**: Required for encrypted configurations; disable only if not using secure storage

## Architecture Notes

### Default Behavior

The feature flag system uses a **fail-safe default** approach:
- If `.chezmoidata.toml` is missing features, all flags default to `true`
- This ensures the dotfiles work out-of-the-box without configuration

### Performance Impact

- **Enabled features**: Include additional configurations and may load more shell plugins
- **Disabled features**: Reduce startup time and memory usage by excluding unnecessary components

### Template Resolution

Feature flags are resolved during chezmoi template processing, not at runtime. This means:
- Changes require `chezmoi apply` to take effect
- No runtime performance penalty for checking feature status
- Configurations are pre-compiled based on active features

## Troubleshooting

### Check Current Features

```bash
# View active features
echo $DOTFILES_FEATURES

# View profile and theme
echo "Profile: $DOTFILES_PROFILE"
echo "Theme: $DOTFILES_THEME"
```

### Verify Configuration

```bash
# Check chezmoi data
chezmoi data

# Test template processing
chezmoi execute-template '{{ .features.zsh }}'
```

### Reset to Defaults

If you encounter issues, reset to default configuration:

```toml
[features]
zsh = true
nvim = true
tmux = true
gui = true
secrets = true
```

---

**Last Updated**: 2026-01-31
**Dotfiles Version**: v0.2.487
