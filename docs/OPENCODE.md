<!--
  Role:     Repo-scoped instructions for the OpenCode CLI when operating
            inside this repository. Mirrors CLAUDE.md but targets OpenCode's
            conventions/discovery.
  Audience: OpenCode, this repo only.

  Distinct from:
    - CLAUDE.md           — same intent, but for Claude Code.
    - defaults/dot_claude/CLAUDE.md: PERSONAL cross-project Claude Code
                             preferences, deployed to ~/.claude/CLAUDE.md by chezmoi.

  Keep CLAUDE.md and OPENCODE.md in sync on repo-level conventions (layout,
  naming, CI, testing). If they drift, CLAUDE.md is the source of truth.
-->

# OPENCODE.md — AI Assistant Guidelines for Dotfiles Repository

## Chezmoi Source Directory Conventions

This is a **chezmoi-managed** dotfiles repository. Files here are *source templates*,
not the deployed config files. Understanding the naming conventions is critical.

`.chezmoiroot` contains `defaults`, so the chezmoi source tree is `defaults/`:
every path below that starts with `dot_`, `private_` or `.chezmoi` lives under `defaults/`.

### File Naming Rules

| Prefix/Suffix    | Meaning                                              |
|------------------|------------------------------------------------------|
| `dot_`           | Deployed with a leading `.` (e.g., `dot_zshrc` -> `.zshrc`) |
| `executable_`    | Deployed with `+x` permission                        |
| `private_`       | Deployed with `0600` permissions                      |
| `.tmpl`          | **Go template** — processed by chezmoi before deployment |
| `run_onchange_`  | Script that runs when its rendered content changes    |
| `encrypted_`     | Age-encrypted file, decrypted at deploy time          |
| `modify_`        | Script that edits the existing target in place        |

### Critical: Template vs Non-Template Files

Many shell config files exist **only** as `.tmpl` variants. When reading files:

- `defaults/dot_config/shell/00-core-paths.sh` does **NOT** exist
- `defaults/dot_config/shell/00-core-paths.sh.tmpl` **DOES** exist (this is the source)

**Rule**: If a `.sh` or `.zsh` file is not found, always try appending `.tmpl`.

Files that are templates (use Go template syntax like `{{ .variable }}`):

- `defaults/dot_config/shell/*.sh.tmpl`: the templated shell layers
- `defaults/dot_config/zsh/dot_zshrc.tmpl`: main zsh config
- `defaults/dot_config/zsh/rc.d/*.tmpl`: templated zsh startup modules
- `defaults/dot_gitconfig.tmpl`: git configuration
- `defaults/private_dot_ssh/config.tmpl`: SSH configuration
- `defaults/private_dot_netrc.tmpl`: netrc credentials

`defaults/modify_private_dot_npmrc` is not a template: it is a chezmoi `modify_` script that edits `~/.npmrc` in place, so `npm login` tokens are kept.

Files that are **NOT** templates (plain files, no `.tmpl` suffix):

- `defaults/dot_config/shell/05-core-safety.sh`, `10-secrets.sh`, `40-ls-colors.sh`: plain shell scripts
- `defaults/dot_config/zsh/rc.d/00-alias-shims.zsh`, `05-ssh-agent.zsh`, `20-zinit.zsh`, `40-bell.zsh`, `50-login-fortune.zsh`: plain zsh
- Most files under `defaults/dot_config/nvim/` (`defaults/dot_config/starship.toml.tmpl`, by contrast, is a template)

### Reading Template Files

Template files contain Go template directives like:

```
{{ if eq .chezmoi.os "darwin" }}
  # macOS-specific config
{{ end }}
```

Data variables come from `defaults/.chezmoidata.toml` and `defaults/.chezmoidata/` (profiles, features, theme, tools, hardware presets).
User-specific values (git identity, age keys) come from `~/.config/chezmoi/chezmoi.toml`.

### Repository Layout

```
defaults/                     # chezmoi source root (.chezmoiroot)
  .chezmoidata.toml           # Feature flags, profile, version
  .chezmoitemplates/          # Reusable template partials (aliases, functions, theme-name)
  dot_config/                 # XDG configs (~/.config/*), the largest directory
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
bin/                          # dot dispatcher (bash and PowerShell)
plugins/                      # One plugin per dot domain
lib/dot/                      # Shared bash library
scripts/                      # Repo-only scripts (tests, ops, security, diagnostics)
docs/                         # Documentation
install.sh                    # Bootstrap installer
```

### Shell Startup Chain

```
~/.zshenv (defaults/dot_zshenv)          → XDG vars, PATH, ZDOTDIR
~/.config/zsh/.zshrc (dot_zshrc.tmpl)    → Main orchestrator
  → rc.d/00-alias-shims.zsh     → Single-letter fallback commands
  → rc.d/05-ssh-agent.zsh       → SSH agent + YubiKey
  → rc.d/10-env.zsh.tmpl        → Environment variables
  → rc.d/20-zinit.zsh           → Plugin manager (deferred)
  → rc.d/30-options.zsh.tmpl    → History, keybindings, completions
  → rc.d/35-rust-target.zsh.tmpl, 40-bell.zsh, 45-standards.zsh, 50-login-fortune.zsh, 99-alias-wrapper.zsh
  → rc.d.local/*.zsh            → User-local extensions (not managed)
  → shell/00-core-paths.sh.tmpl → Full PATH construction
  → shell/05-core-safety.sh     → Safety defaults
  → shell/90-ux-aliases.sh.tmpl → Core aliases (eager)
  → [deferred] mise, atuin, starship, zoxide, fzf
  → [lazy] shell/91-ux-aliases-lazy.sh.tmpl → Tool aliases
```

### Key Data Files

- `defaults/.chezmoidata.toml`: profile, feature flags, tool settings; `defaults/.chezmoidata/hardware.toml` holds the machine presets
- `defaults/dot_config/mise/conf.d/00-dotfiles.toml`: mise tool versions (node, python, go, rust, etc.); the writable `~/.config/mise/config.toml` is mise-owned and not chezmoi-managed
- `defaults/dot_config/starship.toml.tmpl`: Prompt configuration

### Testing

- Test framework: `tests/framework/`
- Unit tests: `tests/unit/`
- Tests execute bash source files directly — they do NOT use Go template syntax
