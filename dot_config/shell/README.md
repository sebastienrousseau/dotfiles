# Dotfiles

Welcome to your universally compatible, high-performance dotfiles configuration, managed by [chezmoi](https://www.chezmoi.io/).

## Discover

- **Universal Support**: Works seamlessly on macOS, Linux (Ubuntu/Debian), and Windows (WSL).
- **Instant Startup**: Optimized with `zcompile` and lazy-loading for <10ms startup time.
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
To install these dotfiles on a new machine, simply run:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.482/install.sh)"
```

This command will:
1. Install `chezmoi`.
2. Clone this repository.
3. Install required packages (Homebrew/Apt).
4. Apply the configurations to your home directory.

---

## Keep it current

### macOS
Updates are handled via [Homebrew](https://brew.sh/).
1. Edit `~/.dotfiles/dot_config/shell/Brewfile.cli` and `~/.dotfiles/dot_config/shell/Brewfile.cask`.
2. Run `chezmoi apply`.
   - This triggers `run_onchange_darwin_install-packages.sh.tmpl`, which runs `brew bundle` for CLI and GUI packages.
   - Optional: `mas` installs App Store apps from `~/.config/mas/masapps.txt`.
   - Optional: `duti` applies default app bindings from `~/.config/duti/defaults.duti`.

### VS Code extensions
1. Edit `~/.config/vscode/extensions.txt`.
2. Run `chezmoi apply` to install missing extensions (if `code` is available).

### Linux and WSL
Updates are handled via `apt-get` (Ubuntu/Debian).
1. Run `chezmoi apply`.
   - This checks for package updates defined in `run_onchange_linux_install-packages.sh.tmpl`.
   - Optional Flatpak list is read from `~/.config/flatpak/flatpak.list`.

### Vim plugins
1. Edit `~/.dotfiles/dot_vimrc`.
2. Run `chezmoi apply`.
   - This automatically runs `vim +PlugInstall +PlugClean +qa`.

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

The configuration is managed in `~/.dotfiles`.

```
~/.dotfiles/
├── dot_zshrc.tmpl          # Main Zsh configuration (template)
├── dot_vimrc               # Vim configuration
├── dot_tmux.conf           # Tmux configuration
├── run_onchange_...sh.tmpl # Package installation scripts
├── dot_config/
│   ├── shell/           # Main Config Directory
│   │   ├── aliases.sh.tmpl # Generates aliases.sh (Modular)
│   │   ├── paths.sh.tmpl   # Generates paths.sh (Monolithic)
│   │   └── functions.sh.tmpl # Generates functions.sh
│   └── starship.toml.tmpl  # Starship configuration
└── .chezmoitemplates/      # Reusable Logic
    ├── aliases/            # Alias definitions (grouped by tool)
    ├── functions/          # Shell functions
    └── paths/              # (Legacy) Path definitions
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
dot apply      # Apply dotfiles (chezmoi apply)
dot sync       # Alias of apply
dot update     # Pull latest changes and apply
dot diff       # Show diff (excludes scripts/install/tests)
dot remove     # Safely remove a managed file
dot drift      # Drift dashboard (chezmoi status)
dot history    # Shell history analysis
dot tools      # Show dot utils
dot keys       # Show keybindings
dot tune       # Apply OS tuning (opt-in)
dot secrets    # Edit encrypted secrets (age)
dot upgrade    # Update flake, plugins, and dotfiles
dot new        # Scaffold a project template (python/go/node)
dot log-rotate # Rotate ~/.local/share/dotfiles.log
dot doctor
dot sandbox
dot benchmark
dot theme
dot wallpaper
dot ssh-key
dot secrets-create
dot fonts
dot firewall
dot telemetry
dot dns-doh
dot encrypt-check
dot backup
dot lock-screen
dot usb-safety
dot secrets-init
dot edit
dot docs
dot learn     # Interactive tour (requires gum)
dot help
```

### Nix

```bash
cd ~/.dotfiles
nix develop
```

### Secrets

```bash
dot secrets-init
dot secrets
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

Set the theme in `.chezmoidata.toml`:

```toml
theme = "tokyonight-night"
terminal_font_family = "JetBrains Mono"
terminal_font_size = 12
```

Available themes:
- `tokyonight-night` (best dark default)
- `tokyonight-day` (best light default)
- `tokyonight-storm`
- `tokyonight-moon`
- `catppuccin-mocha`
- `dracula`
- `gruvbox-dark`
- `gruvbox-light`
- `nord`
- `onedark`
- `onelight`
- `solarized-dark`
- `solarized-light`
- `catppuccin-mocha`
- `catppuccin-latte`
- `rose-pine`
- `rose-pine-moon`
- `rose-pine-dawn`
- `everforest-dark`
- `everforest-light`
- `kanagawa-wave`
- `kanagawa-dragon`
- `kanagawa-lotus`

### DevContainer and Codespaces

```
.devcontainer/devcontainer.json
```

### Add aliases
1. Navigate to `~/.dotfiles/.chezmoitemplates/aliases/`.
2. Create a new file (e.g., `mytool/mytool.aliases.sh`) or edit an existing one.
3. Add your aliases.
4. Run `chezmoi apply`.

**Note:** Files in `macOS/` are only included on macOS systems.

### Add functions
1. Navigate to `~/.dotfiles/.chezmoitemplates/functions/`.
2. Create a new `.sh` file.
3. Define your function with a usage comment.
4. Run `chezmoi apply`.

## Performance
- **Lazy Loading**: Heavy tools (like `nvm`, `rbenv`) are lazy-loaded. They only initialize when you type the command.
- **Zcompile**: Your `.zshrc` and generated config files are automatically compiled to `.zwc` bytecode for faster parsing.

## Test
This repository includes GitHub Actions CI to test the configuration on macOS, Ubuntu, and Windows for every Pull Request.

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
