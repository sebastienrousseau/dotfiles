# Feature Flags

Feature flags control which components are enabled in your dotfiles setup. They're defined in `.chezmoidata.toml` and used in template files to conditionally include or exclude functionality.

## Configuration

Feature flags live in `.chezmoidata.toml`:

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
|------|---------|---------|--------------|--------|
| `zsh` | `true` | Zsh shell configuration and optimizations | - | Zsh configs, aliases, shell enhancements |
| `fish` | `true` | Fish shell configuration | - | Fish configs, aliases, shell enhancements |
| `nushell` | `true` | Nushell for structured data pipelines | - | Nushell setup, plugins, environment |
| `nvim` | `true` | Neovim editor configuration | - | Neovim configs, plugins, editor settings |
| `tmux` | `true` | Tmux terminal multiplexer | - | Tmux configs, key bindings, sessions |
| `zellij` | `false` | Zellij terminal workspace | - | Zellij layouts, themes, keybindings |
| `gui` | `true` | GUI application configurations | Desktop environment | GUI app configs, window managers |
| `secrets` | `true` | Secrets management and encryption | GPG, Age, SSH keys | Encrypted configs, credential storage |
| `ai_tools` | `true` | AI CLI tool integrations | - | AI tool aliases and unified context |
| `alias_wrapper` | `false` | Alias hardening and validation | - | Safety wrappers for destructive commands |

## Validation

The `dot` CLI provides commands for system validation:

- **`dot smoke-test`** — verifies that core toolchains (Rust, Go, AI) are functional
- **`dot chaos`** — (destructive) corrupts configs to test self-healing via `dot heal`
- **`dot health`** — comprehensive diagnostic across paths, files, and dependencies

## Structured Logging

Set `export DOTFILES_JSON_LOG=1` to enable JSON-structured output for all bootstrap and provisioning events.

## How Feature Flags Work

### Template Processing

Feature flags are processed in the Zsh configuration template (`dot_config/zsh/dot_zshrc.tmpl`) where they:

1. **Set defaults** — if not explicitly defined, all features default to `true`
2. **Export environment variables** — active features are exported as `DOTFILES_FEATURES`
3. **Enable conditional loading** — allow selective inclusion of shell configurations

### Example Usage

```bash
# In template files, feature flags are referenced as:
{{- $features := default (dict "zsh" true "nvim" true "tmux" true "gui" true "secrets" true) .features -}}

# Export enabled features to environment
export DOTFILES_FEATURES="{{ join "," $enabled }}"
```

### Runtime Access

```bash
# View all enabled features
echo $DOTFILES_FEATURES

# Check if a specific feature is enabled
if [[ "$DOTFILES_FEATURES" == *"nvim"* ]]; then
    echo "Neovim configuration is active"
fi
```

## Modifying Feature Flags

### Enable or Disable Features

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

```bash
chezmoi apply
```

### Profile-Specific Overrides

Override feature flags per machine in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
gui = false  # Disable GUI on this machine
```

## Dependencies

- **zsh** — core shell functionality; recommended to keep enabled
- **nvim** — independent; disable if using another editor
- **tmux** — independent; disable if not using a multiplexer
- **gui** — requires a desktop environment; automatically ignored on headless systems
- **secrets** — required for encrypted configurations; disable only if not using secure storage

## Architecture Notes

### Default Behavior

The feature flag system uses a **fail-safe default** approach:
- If `.chezmoidata.toml` is missing features, all flags default to `true`
- This ensures the dotfiles work out of the box without configuration

### Performance Impact

- **Enabled features** include additional configs and may load more shell plugins
- **Disabled features** reduce startup time by excluding unnecessary components

### Template Resolution

Feature flags are resolved during chezmoi template processing, not at runtime:
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

```toml
[features]
zsh = true
nvim = true
tmux = true
gui = true
secrets = true
```
