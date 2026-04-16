# Reference: Environment Variables

All environment variables that affect `.dotfiles` behaviour.

## User-Settable

Variables you can set in your shell to change behaviour.

| Variable | Default | Effect |
|:---|:---|:---|
| `DOTFILES_VERBOSE` | unset | Verbose output from `dot` commands |
| `DOTFILES_NONINTERACTIVE` | unset | Skip interactive prompts (for CI) |
| `DOTFILES_SILENT` | unset | Suppress non-error output |
| `DOTFILES_DEBUG` | unset | Print shell-init timing to stderr |
| `DOTFILES_SOURCE_DIR` | `~/.dotfiles` | Override the source directory |
| `DOTFILES_WALLPAPER_DIR` | `~/Pictures/Wallpapers` | Custom wallpaper directory |
| `DOTFILES_CACHE_DIR` | `~/.cache/dotfiles` | Override cache location |
| `DOTFILES_STATE_DIR` | `~/.local/state/dotfiles` | Override state directory |
| `DOTFILES_TUNING` | `0` | Enable OS tuning (`dot tune`) |
| `EDITOR` | `nvim` | Editor used by `dot edit` and `sops` |
| `PAGER` | `less` | Pager used by `dot manual text` |

## Auto-Populated

Variables the dotfiles set in your shell for tool consumption.

| Variable | Value | Source |
|:---|:---|:---|
| `XDG_CONFIG_HOME` | `~/.config` | `dot_zshenv` / `dot_config/fish/conf.d/env.fish.tmpl` |
| `XDG_CACHE_HOME` | `~/.cache` | ditto |
| `XDG_DATA_HOME` | `~/.local/share` | ditto |
| `XDG_STATE_HOME` | `~/.local/state` | ditto |
| `PATH` | managed order | `dot_config/shell/00-core-paths.sh.tmpl` |
| `BUN_INSTALL` | `~/.bun` | `env.fish.tmpl` |
| `PIPX_HOME` | `~/.local/share/pipx` | ditto |
| `PIPX_BIN_DIR` | `~/.local/bin` | ditto |
| `BUILDS_TMPDIR` | `/tmp/builds` | `dot_zshenv` (created on shell init) |
| `CARGO_TARGET_DIR` | (from `~/.cargo/config.toml`) | `target-dir = "/tmp/builds/cargo"` |
| `GOCACHE` | `/tmp/builds/go-cache` | `mise [env]` |
| `GOTMPDIR` | `/tmp/builds/go-tmp` | `mise [env]` |
| `PIP_CACHE_DIR` | `/tmp/builds/pip-cache` | `mise [env]` |
| `UV_CACHE_DIR` | `/tmp/builds/uv-cache` | `mise [env]` |
| `ZIG_LOCAL_CACHE_DIR` | `/tmp/builds/zig-cache` | `mise [env]` |
| `ZIG_GLOBAL_CACHE_DIR` | `/tmp/builds/zig-global-cache` | `mise [env]` |
| `HOMEBREW_PREFIX` | `/opt/homebrew` or `/usr/local` | `dot_zshenv` (macOS) |
| `MANPATH` | homebrew-adjusted | ditto |
| `MISE_EXPERIMENTAL` | `1` | `~/.config/mise/config.toml` |
| `GITHUB_TOKEN` | from `gh auth token` | `~/.config/mise/config.toml` |

## Read by Tools

Variables set by upstream tools and respected by `.dotfiles`.

| Variable | Used for |
|:---|:---|
| `SHELL` | Detect default shell |
| `TERM` | Terminal capabilities (e.g. `xterm-256color`) |
| `COLORTERM` | True-color detection (`truecolor`) |
| `LANG` / `LC_ALL` | Locale (must be UTF-8) |
| `HOME` | User home directory |
| `USER` | Username |
| `SSH_AUTH_SOCK` | ssh-agent socket |
| `GPG_TTY` | GPG pinentry TTY |

## CI-Specific

Variables relevant in GitHub Actions.

| Variable | Purpose |
|:---|:---|
| `CI` | Set to `true` in CI; disables prompts |
| `GITHUB_ACTIONS` | GHA-specific; enables step summary output |
| `CHEZMOI_VERSION` | Pinned chezmoi version for CI |
| `COVERAGE_THRESHOLD` | Test coverage threshold (100 in enforced CI) |
| `DOTFILES_TEST_MODE` | Skip network-dependent tests |

## Secret-Related

| Variable | Purpose |
|:---|:---|
| `SOPS_AGE_KEY_FILE` | Override `~/.config/age/keys.txt` path |
| `SOPS_AGE_RECIPIENTS` | Override recipients for new encryption |
| `CHEZMOI_AGE_IDENTITY` | Override age identity for chezmoi decrypt |

> Warning: never set these to values stored in plaintext config. Use a password manager or ephemeral injection.

## Startup Order

Shell-loaded variables follow this precedence (later wins):

1. System defaults (`/etc/environment`, `/etc/profile`)
2. Homebrew shellenv (macOS)
3. `~/.zshenv` (earliest user-level file; sets XDG + PATH bootstrap)
4. `~/.zprofile` or `~/.config/fish/conf.d/*.fish`
5. `~/.zshrc` or `~/.config/fish/config.fish`
6. `mise activate` — injects tool-specific env
7. Per-project `.envrc` via direnv (opt-in)

To debug: `DOTFILES_DEBUG=1 zsh -i -c exit` prints timing for each stage.

## Unsetting

To clean up environment pollution:

```sh
# Show current dotfiles-set vars
env | grep -E '^(DOTFILES_|XDG_|BUILDS_)'

# Unset one
unset DOTFILES_DEBUG

# Reset to defaults (restart shell)
exec $SHELL -l
```

## See Also

- [Configuration Files](02-config-files.md)
- [Feature Flags](05-feature-flags.md)
- [First Install](../02-tutorials/01-first-install.md)
