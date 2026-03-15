# OPENCODE.md — AI Assistant Guidelines for Dotfiles Repository

## Chezmoi Source Directory Conventions

This is a **chezmoi-managed** dotfiles repository. Files here are *source templates*,
not the deployed config files. Understanding the naming conventions is critical.

### File Naming Rules

| Prefix/Suffix    | Meaning                                              |
|------------------|------------------------------------------------------|
| `dot_`           | Deployed with a leading `.` (e.g., `dot_zshrc` -> `.zshrc`) |
| `executable_`    | Deployed with `+x` permission                        |
| `private_`       | Deployed with `0600` permissions                      |
| `.tmpl`          | **Go template** — processed by chezmoi before deployment |
| `run_onchange_`  | Script that runs when the target file changes         |
| `encrypted_`     | Age-encrypted file, decrypted at deploy time          |

### Critical: Template vs Non-Template Files

Many shell config files exist **only** as `.tmpl` variants. When reading files:

- `dot_config/shell/00-core-paths.sh` does **NOT** exist
- `dot_config/shell/00-core-paths.sh.tmpl` **DOES** exist (this is the source)

**Rule**: If a `.sh` or `.zsh` file is not found, always try appending `.tmpl`.

Files that are templates (use Go template syntax like `{{ .variable }}`):
- `dot_config/shell/*.sh.tmpl` — all shell layer files
- `dot_config/zsh/dot_zshrc.tmpl` — main zsh config
- `dot_config/zsh/rc.d/*.tmpl` — zsh startup modules
- `dot_gitconfig.tmpl` — git configuration
- `private_dot_ssh/config.tmpl` — SSH configuration
- `dot_npmrc.tmpl` — npm configuration
- `private_dot_netrc.tmpl` — netrc credentials

Files that are **NOT** templates (plain files, no `.tmpl` suffix):
- `dot_config/shell/00-container-detect.sh` — plain shell script
- `dot_config/shell/90-theme-switch.sh` — plain shell script
- `dot_config/zsh/rc.d/00-alias-shims.zsh` — plain zsh
- `dot_config/zsh/rc.d/05-ssh-agent.zsh` — plain zsh
- Most files under `dot_config/nvim/`, `dot_config/starship.toml.tmpl`, etc.

### Reading Template Files

Template files contain Go template directives like:
```
{{ if eq .chezmoi.os "darwin" }}
  # macOS-specific config
{{ end }}
```

Data variables come from `.chezmoidata.toml` (profiles, features, theme, tools).
User-specific values (git identity, age keys) come from `~/.config/chezmoi/chezmoi.toml`.

### Repository Layout

```
.chezmoidata.toml           # Feature flags, profiles, version
.chezmoitemplates/          # Reusable template partials (aliases, functions, paths)
dot_config/                 # XDG configs (~/.config/*) — largest directory
  zsh/                      # Zsh configuration
    dot_zshrc.tmpl          # Main zsh orchestrator
    rc.d/                   # Startup modules (sourced in order)
  shell/                    # POSIX shell layers (paths, safety, aliases, functions)
  nvim/                     # Neovim configuration (Lua)
  mise/                     # mise version manager config
  starship.toml.tmpl        # Starship prompt config
  atuin/                    # Atuin shell history
  bat/                      # bat (cat replacement) config
  ghostty/                  # Ghostty terminal config
  kitty/                    # Kitty terminal config
  alacritty/                # Alacritty terminal config
dot_local/bin/              # User scripts (~/.local/bin)
scripts/                    # Repo-only scripts (tests, ops, security, diagnostics)
docs/                       # Documentation (30+ files)
install.sh                  # Bootstrap installer
```

### Shell Startup Chain

```
~/.zshenv (dot_zshenv)           → XDG vars, PATH, ZDOTDIR
~/.config/zsh/.zshrc (dot_zshrc.tmpl) → Main orchestrator
  → rc.d/00-alias-shims.zsh     → Single-letter fallback commands
  → rc.d/05-ssh-agent.zsh       → SSH agent + YubiKey
  → rc.d/10-env.zsh.tmpl        → Environment variables
  → rc.d/20-zinit.zsh.tmpl      → Plugin manager (deferred)
  → rc.d/30-options.zsh.tmpl    → History, keybindings, completions
  → rc.d/40-bell.zsh.tmpl       → Bell settings
  → rc.d/50-login-fortune.zsh.tmpl → Login greeting
  → shell/00-core-paths.sh.tmpl → Full PATH construction
  → shell/05-core-safety.sh.tmpl → Safety defaults
  → shell/90-ux-aliases.sh.tmpl → Core aliases (eager)
  → [deferred] mise, atuin, starship, zoxide, fzf
  → [lazy] shell/91-ux-aliases-lazy.sh.tmpl → Tool aliases
```

### Key Data Files

- `.chezmoidata.toml` — All configuration: profiles, feature flags, tool settings
- `dot_config/mise/config.toml` — mise tool versions (node, python, go, rust, etc.)
- `dot_config/starship.toml.tmpl` — Prompt configuration

### Testing

- Test framework: `tests/framework/`
- Unit tests: `tests/unit/`
- Tests execute bash source files directly — they do NOT use Go template syntax
