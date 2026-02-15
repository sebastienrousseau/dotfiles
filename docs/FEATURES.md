# Customize Your Setup

Your environment should fit you. Dotfiles makes that exact.

Choose what ships on each machine. Keep what matters. Cut what does not.

## What Ships

Select the parts of your dotfiles to include or skip:

- **Shell Experience (zsh)** - Enhanced command line with smart completions, syntax highlighting, and productivity shortcuts
- **Code Editor (nvim)** - Neovim configured for development with plugins, themes, and language support
- **Terminal Management (tmux)** - Window splitting, session management, and advanced terminal features
- **Desktop Apps (gui)** - Configurations for desktop applications and window managers
- **Security Tools (secrets)** - Encrypted credential storage and secure configuration management

## Set It Once

Create a simple configuration file to choose your features:

```toml
# Save this as .chezmoidata.toml in your dotfiles directory
[features]
zsh = true      # Include enhanced shell setup
nvim = true     # Include code editor configuration
tmux = true     # Include terminal management
gui = true      # Include desktop app configs
secrets = true  # Include security tools
```

Set any feature to `false` to exclude it from your setup.

## What Each Feature Includes

| What It Does | Always Active | What You Get | Good For |
|-------------|---------------|--------------|----------|
| **Shell Experience** | ✅ Recommended | Smart completions, aliases, themes, productivity shortcuts | Everyone - this makes your command line much better |
| **Code Editor** | Optional | Neovim with plugins, syntax highlighting, development tools | Developers and anyone who edits text files regularly |
| **Terminal Management** | Optional | Window splitting, session saving, advanced terminal features | Power users who work extensively in the terminal |
| **Desktop Apps** | Optional | GUI application settings, window manager configs | Users with desktop environments (not servers) |
| **Security Tools** | Optional | Encrypted storage for passwords and API keys | Anyone handling sensitive credentials |

## Common Scenarios

### Minimal Server Setup
Running headless? Skip the desktop layer:
```toml
[features]
zsh = true      # Keep the great shell experience
nvim = true     # Keep the editor for config files
tmux = true     # Keep terminal management for remote work
gui = false     # Skip desktop apps
secrets = true  # Keep security tools
```

### Developer Workstation
Full‑feature setup for development:
```toml
[features]
zsh = true      # Enhanced shell for productivity
nvim = true     # Full development environment
tmux = true     # Advanced terminal management
gui = true      # Desktop integration
secrets = true  # Secure credential management
```

### Light Setup
Only the essentials:
```toml
[features]
zsh = true      # Basic shell improvements
nvim = false    # Use your existing editor
tmux = false    # Use simple terminal
gui = false     # No desktop customization
secrets = false # Use system keyring
```

## See What's Active

Check which features are currently enabled:

```bash
# See your active features
echo $DOTFILES_FEATURES

# Example output: zsh,nvim,tmux,secrets
```

## Making Changes

### Change Your Setup

1. **Edit your configuration** - Open `.chezmoidata.toml` in your dotfiles directory
2. **Update features** - Change `true` to `false` for any feature you want to remove
3. **Apply changes** - Run `chezmoi apply` to update your setup

```bash
# After editing .chezmoidata.toml
chezmoi apply
```

Your shell will reload automatically with the new configuration.

### Machine-Specific Setup

Different needs on different machines? Override settings locally:

```toml
# Save as ~/.config/chezmoi/chezmoi.toml
[data.features]
gui = false  # Turn off desktop apps on this machine only
```

This overrides your main configuration without changing it for other machines.

## What's Safe to Turn Off?

### Always Safe to Disable
- **nvim** - Use your preferred editor instead
- **tmux** - Use your terminal as-is
- **gui** - Perfect for servers or minimal setups

### Usually Want to Keep
- **zsh** - The shell improvements benefit everyone
- **secrets** - Only disable if you handle credentials differently

### Automatic Behavior
- **gui** features are automatically ignored on servers without desktop environments
- If you don't create a configuration file, everything is enabled by default
- Your dotfiles work immediately without any setup required

## Performance Notes

Fewer features mean faster startup. Each disabled feature:
- Reduces shell startup time
- Uses less memory
- Creates a cleaner environment
- Loads faster on remote connections

Example impact: Disabling GUI and tmux features can reduce shell startup by 50-100ms on slower systems.

## Need Help?

### Check What's Currently Active

```bash
# See your active features
echo $DOTFILES_FEATURES

# Check your setup details
echo "Profile: $DOTFILES_PROFILE"
echo "Theme: $DOTFILES_THEME"
```

### Something Not Working?

1. **Make sure changes were applied**: Run `chezmoi apply` after editing configuration
2. **Check your setup**: Use `chezmoi data` to see current settings
3. **Test a specific feature**: Try `chezmoi execute-template '{{ .features.zsh }}'`

### Start Over

Reset everything to the defaults:

```toml
# Put this in .chezmoidata.toml
[features]
zsh = true      # Great shell experience
nvim = true     # Code editor setup
tmux = true     # Terminal management
gui = true      # Desktop integration
secrets = true  # Security tools
```

This gives you the full experience while you figure out what you want to customize.

---

**Last Updated**: 2026-02-15
**Dotfiles Version**: v0.2.482
