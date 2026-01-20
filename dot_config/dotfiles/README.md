# Dotfiles (Universal Config)

Welcome to your universally compatible, high-performance dotfiles configuration, managed by [chezmoi](https://www.chezmoi.io/).

## 🚀 Features

- **Universal Support**: Works seamlessly on macOS, Linux (Ubuntu/Debian), and Windows (WSL).
- **Instant Startup**: Optimized with `zcompile` and lazy-loading for <10ms startup time.
- **Modern Tooling**: Replaces legacy Unix tools with Rust-based alternatives (`eza`, `bat`, `ripgrep`, `zoxide`).
- **Starship Prompt**: A fast, customizable, cross-shell prompt.
- **Optimized Vim**: `vim-plug` is managed automatically with performant lazy-loading logic.
- **Modular Design**: Configuration is split into small, manageable templates in `~/.local/share/chezmoi`.

---

## 📥 Installation

### One-Line Bootstrap
To install these dotfiles on a new machine, simply run:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply sebastienrousseau
```

This command will:
1. Install `chezmoi`.
2. Clone this repository.
3. Install required packages (Homebrew/Apt).
4. Apply the configurations to your home directory.

---

## 🔄 How to Update

This configuration uses `chezmoi`'s "run_onchange" scripts to keep your system in sync.

### macOS
Updates are handled via [Homebrew](https://brew.sh/).
1. Edit `~/.local/share/chezmoi/dot_config/dotfiles/Brewfile`.
2. Run `chezmoi apply`.
   - This triggers `run_onchange_install_packages.sh.tmpl`, which runs `brew bundle`.

### Linux & WSL
Updates are handled via `apt-get` (Ubuntu/Debian).
1. Run `chezmoi apply`.
   - This checks for package updates defined in `run_onchange_install_packages.sh.tmpl`.

### Vim Plugins
1. Edit `~/.local/share/chezmoi/dot_vimrc`.
2. Run `chezmoi apply`.
   - This automatically runs `vim +PlugInstall +PlugClean +qa`.

---

## 🚚 Migration Guide (Legacy -> Chezmoi)

If you are migrating from an old `~/.dotfiles` setup:

1. **Backup**:
   ```bash
   mv ~/.dotfiles ~/.dotfiles.legacy
   cp ~/.zshrc ~/.zshrc.bak
   ```

2. **Initialize Chezmoi**:
   ```bash
   chezmoi init --apply sebastienrousseau
   ```

3. **Verify**:
   - Restart your shell.
   - Check that `~/.config/dotfiles` exists (this is where the *generated* scripts live).
   - Check that `~/.local/share/chezmoi` exists (this is the *source*).

4. **Clean Up**:
   - Once verified, you can safely delete `~/.dotfiles.legacy` and `.zshrc.bak`.

---

## 📂 Structure

The configuration is managed in `~/.local/share/chezmoi`.

```
~/.local/share/chezmoi/
├── dot_zshrc.tmpl          # Main Zsh configuration (template)
├── dot_vimrc               # Vim configuration
├── dot_tmux.conf           # Tmux configuration
├── run_onchange_...sh.tmpl # Package installation scripts
├── dot_config/
│   ├── dotfiles/           # Main Config Directory
│   │   ├── aliases.sh.tmpl # Generates aliases.sh
│   │   ├── paths.sh.tmpl   # Generates paths.sh
│   │   └── functions.sh.tmpl # Generates functions.sh
│   └── starship.toml.tmpl  # Starship configuration
└── .chezmoitemplates/      # Reusable Logic
    ├── aliases/            # Alias definitions (grouped by tool)
    ├── functions/          # Shell functions
    └── paths/              # Path definitions
```

## 🛠 Usage

### Applying Changes
After editing any file in `~/.local/share/chezmoi`, apply the changes to your home directory:

```bash
chezmoi apply
```

To see what will change before applying:

```bash
chezmoi diff
```

### Adding New Aliases
1. Navigate to `~/.local/share/chezmoi/.chezmoitemplates/aliases/`.
2. Create a new file (e.g., `mytool/mytool.aliases.sh`) or edit an existing one.
3. Add your aliases.
4. Run `chezmoi apply`.

**Note:** Files in `macOS/` are only included on macOS systems.

### Adding New Functions
1. Navigate to `~/.local/share/chezmoi/.chezmoitemplates/functions/`.
2. Create a new `.sh` file.
3. Define your function with a usage comment.
4. Run `chezmoi apply`.

## ⚡ Performance Tips
- **Lazy Loading**: Heavy tools (like `nvm`, `rbenv`) are lazy-loaded. They only initialize when you type the command.
- **Zcompile**: Your `.zshrc` and generated config files are automatically compiled to `.zwc` bytecode for faster parsing.

## 🧪 Testing
This repository includes GitHub Actions CI to test the configuration on macOS, Ubuntu, and Windows for every Pull Request.
