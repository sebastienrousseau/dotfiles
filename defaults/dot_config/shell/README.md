# Dotfiles

Welcome to your universally compatible, high-performance dotfiles configuration, managed by [chezmoi](https://www.chezmoi.io/).

## Discover

- **Universal Support**: Works seamlessly on macOS, Linux (Ubuntu/Debian), and Windows (WSL).
- **Fast Startup**: Optimized with `zcompile` and lazy-loading. Benchmarks vary by machine; use `DOTFILES_FAST=1` for the quickest first prompt.
- **Modern Core**: Replaces legacy Unix tools with Rust-based alternatives:
  - `eza` (ls)
  - `bat` (cat)
  - `ripgrep` (grep)
  - `zoxide` (cd)
  - `atuin` (history)
  - `yazi` (files)
  - `zellij` (multiplexer)
- **Starship Prompt**: A fast, customizable, cross-shell prompt.
- **Optimized Vim**: Vim settings are kept minimal and fast by default.
- **Modular Design**: Configuration is split into small, manageable templates.

---

## Get started

### Install

Download and SHA256-verify the release-pinned installer using the root README,
then run:

```bash
bash /tmp/dotfiles-install.sh
```

This command will:

1. Install `chezmoi`.
2. Clone this repository.
3. Apply the configurations to your home directory.

Packages are opt-in: run the installer with `--provision` (or set
`DOTFILES_PROVISION=1`) to also install the toolchain (Homebrew/Apt packages,
fonts, language tools) from `install/provision/`. `chezmoi apply` never runs
those scripts, because `install/provision/` sits outside the chezmoi source
root (`defaults/`).

---

## Keep it current

### macOS

Updates are handled via [Homebrew](https://brew.sh/).

1. Edit `~/.dotfiles/defaults/dot_config/shell/Brewfile.cli` and `~/.dotfiles/defaults/dot_config/shell/Brewfile.cask`.
2. Run `chezmoi apply` to deploy them, then `bash ~/.dotfiles/install.sh --provision`.
   - Provisioning runs `install/provision/run_onchange_10-darwin-packages.sh.tmpl`, which runs `brew bundle` for CLI and GUI packages.
   - Optional: `mas` installs App Store apps from `~/.config/mas/masapps.txt` (`run_onchange_30-darwin-mas.sh`).
   - Optional: `duti` applies default app bindings from `~/.config/duti/defaults.duti` (`run_onchange_40-darwin-default-apps.sh`).

### VS Code extensions

1. Edit `~/.dotfiles/defaults/dot_config/vscode/extensions.txt` and run `chezmoi apply` to deploy it to `~/.config/vscode/extensions.txt`.
2. Run `bash ~/.dotfiles/install.sh --provision`: `install/provision/run_onchange_30-vscode-extensions.sh` installs missing extensions (if `code` is available).

### Linux and WSL

Updates are handled via `apt-get` (Ubuntu/Debian).

1. Run `bash ~/.dotfiles/install.sh --provision`.
   - This installs the packages defined in `install/provision/run_onchange_10-linux-packages.sh.tmpl`.
   - Optional Flatpak list is read from `~/.config/flatpak/flatpak.list` (`run_onchange_20-linux-flatpak.sh.tmpl`).

### Vim settings

1. Edit `~/.dotfiles/defaults/dot_vimrc`.
2. Run `chezmoi apply`. The vimrc uses no plugin manager, so there is no plugin install step.

---

## Migrate

If you are migrating from an old `~/.dotfiles` setup:

1. **Backup**:

   ```bash
   mv ~/.dotfiles ~/.dotfiles.legacy
   cp ~/.zshrc ~/.zshrc.bak
   ```

2. **Initialize Chezmoi**:

   ```bash
   git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
   chezmoi apply
   ```

3. **Verify**:
   - Restart your shell.
   - Check that `~/.config/shell` exists (this is where the *generated* scripts live).
   - Check that `~/.dotfiles` exists (this is the *source*).

4. **Clean Up**:
   - Once verified, you can safely delete `~/.dotfiles.legacy` and `.zshrc.bak`.

---

## Structure

The configuration is managed in `~/.dotfiles`. The chezmoi source root is
`defaults/` (set by `.chezmoiroot`).

```text
~/.dotfiles/
├── install/provision/          # Opt-in package scripts (install.sh --provision)
└── defaults/                   # chezmoi source root
    ├── dot_zshrc               # ~/.zshrc stub
    ├── dot_vimrc               # Vim configuration
    ├── run_onchange_...sh.tmpl # Build and refresh hooks run by chezmoi apply
    ├── dot_config/
    │   ├── zsh/dot_zshrc.tmpl  # Main Zsh configuration (template)
    │   ├── tmux/tmux.conf.tmpl # Tmux configuration
    │   ├── shell/              # Shared shell layers
    │   │   ├── 00-core-paths.sh.tmpl          # PATH setup
    │   │   ├── 50-logic-functions*.sh.tmpl    # Function aggregators
    │   │   ├── 51-logic-functions-extra.sh.tmpl
    │   │   ├── 90-ux-aliases.sh.tmpl          # Alias aggregator
    │   │   └── 91-ux-aliases-lazy.sh.tmpl     # Lazy alias stubs
    │   └── starship.toml.tmpl  # Starship configuration
    └── .chezmoitemplates/      # Reusable logic
        ├── aliases/            # Alias definitions (grouped by tool)
        └── functions/          # Shell functions
```

## Use it

### Apply changes

After editing any file in `~/.dotfiles`, apply the changes to your home directory:

```bash
chezmoi apply
```

To see what will change before applying:

```bash
chezmoi diff
```

### Dot CLI

```bash
dot apply      # Shortcut for dot config apply (chezmoi apply)
dot sync       # Shortcut for dot config sync
dot update     # Shortcut for dot system update
dot diff       # Shortcut for dot config diff
dot doctor drift show      # Drift dashboard (chezmoi status)
dot shell history list    # Shell history analysis
dot tool list # Toolchains and their versions
# Keybindings: docs/security/KEYS.md
dot system settings apply       # Apply OS tuning (opt-in)
dot secret edit # Edit encrypted secrets (age)
dot system update    # Update flake, plugins, and dotfiles
dot tool new        # Scaffold a project template (python/go/node/packer/molecule)
dot doctor
dot config apply --sandbox
dot doctor perf measure
dot theme
dot theme wallpaper set
dot secret key new
dot secret new
dot theme font install
dot security firewall apply
dot security telemetry apply
dot security dns apply
dot security disk show
dot doctor backup
dot security lock apply
dot security usb apply
dot secret init
dot edit
dot help --readme
dot help tour     # Interactive tour (requires gum)
dot help
```

### Nix

```bash
cd ~/.dotfiles
nix develop
```

### Secrets

```bash
dot secret init
dot secret edit
```

### Git identity

Set your Git identity in the local `chezmoi` config (not committed):

```bash
chezmoi init --apply --promptDefaults
```

Or edit directly:

```bash
${EDITOR:-nano} ~/.config/chezmoi/chezmoi.toml
```

Fields:

- `git_name`
- `git_email`
- `git_signingkey`
- `git_signingformat`

### Make it yours

Set the theme in `defaults/.chezmoidata.toml`:

```toml
theme = "maui-dark"
terminal_font_family = "JetBrainsMono Nerd Font"
terminal_font_size = 20
```

Run `dot theme list` for the available themes.

### DevContainer and Codespaces

```text
.devcontainer/devcontainer.json
```

### Add aliases

1. Navigate to `~/.dotfiles/defaults/.chezmoitemplates/aliases/`.
2. Create a new file (e.g., `mytool/mytool.aliases.sh`) or edit an existing one.
3. Add your aliases.
4. Run `chezmoi apply`.

**Note:** Files in `macOS/` are only included on macOS systems.

### Add functions

1. Navigate to `~/.dotfiles/defaults/.chezmoitemplates/functions/`.
2. Create a new `.sh` file.
3. Define your function with a usage comment.
4. Run `chezmoi apply`.

## Performance

- **Lazy Loading**: Heavy tools (like `nvm`) are lazy-loaded. They only initialize when you type the command. Add your own with `_dot_lazy` in `~/.config/zsh/rc.d/99-local.zsh`.
- **Zcompile**: Your `.zshrc` and generated config files are automatically compiled to `.zwc` bytecode for faster parsing.
- **Fast Mode**: Set `DOTFILES_FAST=1` to skip heavy startup work (plugins, completions, prompt tooling, AI helpers) for the quickest possible first prompt.
- **Ultra-Fast Mode**: Set `DOTFILES_ULTRA_FAST=1` for minimal init (no rc.d, plugins, completions, or prompt tooling).
- **Perf Mode**: `dot doctor perf show --profile` includes profile output with the startup timings.
- **Deferred Hooks**: Use `DOTFILES_DEFER_COMPINIT=1`, `DOTFILES_DEFER_TOOLS=1`, and `DOTFILES_DEFER_ZINIT_MODE=preexec` to move work after the first command.

## Test

This repository includes GitHub Actions CI to test the configuration on macOS, Ubuntu, and Windows for every Pull Request.
