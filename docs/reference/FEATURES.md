# Feature Flags

Feature flags control which components chezmoi deploys. They're defined in
`.chezmoidata.toml` and evaluated at template processing time — there's no
runtime overhead.

## Configuration

All flags live in `.chezmoidata.toml`. If a flag isn't set, it defaults to
`true` so everything works out of the box.

```toml
[features]
zsh = true
nvim = true
tmux = true
```

## Available Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `zsh` | `true` | Zsh shell configuration and optimizations |
| `fish` | `true` | Fish shell configuration |
| `nushell` | `true` | Nushell for structured data pipelines |
| `starship` | `true` | Starship cross-shell prompt |
| `nvim` | `true` | Neovim editor configuration and plugins |
| `tmux` | `true` | Tmux terminal multiplexer |
| `zellij` | `false` | Zellij terminal workspace |
| `alias_wrapper` | `false` | Safety wrappers for destructive commands |

## Validation

The `dot` CLI provides commands for system validation:

- **`dot health`** — comprehensive diagnostic across paths, files, and dependencies
- **`dot smoke-test`** — verifies that core toolchains (Rust, Go, AI) are functional
- **`dot chaos`** — (destructive) corrupts configs to test self-healing via `dot heal`

## Structured Logging

Set `export DOTFILES_JSON_LOG=1` to enable JSON-structured output for all
bootstrap and provisioning events.

## Modifying Flags

Edit `.chezmoidata.toml` and apply:

```toml
[features]
tmux = false    # disable tmux configuration
zellij = true   # enable zellij instead
```

```bash
chezmoi apply
```

### Per-Machine Overrides

You can override flags on a specific machine in
`~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
gui = false  # disable GUI on this machine
```
