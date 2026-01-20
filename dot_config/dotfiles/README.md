# Dotfiles (Universal Config)

Welcome to your universally compatible, high-performance dotfiles configuration, managed by [chezmoi](https://www.chezmoi.io/).

## 🚀 Features

- **Universal Support**: Works seamlessly on macOS, Linux, and Windows (WSL).
- **Instant Startup**: Optimized with `zcompile` and lazy-loading for <10ms startup time.
- **Modern Tooling**: Replaces legacy Unix tools with Rust-based alternatives:
  - `ls` -> [`eza`](https://github.com/eza-community/eza)
  - `cat` -> [`bat`](https://github.com/sharkdp/bat)
  - `grep` -> [`ripgrep`](https://github.com/BurntSushi/ripgrep)
  - `cd` -> [`zoxide`](https://github.com/ajeetdsouza/zoxide)
  - [`fzf`](https://github.com/junegunn/fzf) for fuzzy finding.
- **Starship Prompt**: A fast, customizable, cross-shell prompt.
- **Modular Design**: Configuration is split into small, manageable templates.

## 📂 Structure

The configuration is managed in `~/.local/share/chezmoi`.

```
~/.local/share/chezmoi/
├── dot_zshrc.tmpl          # Main Zsh configuration (template)
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
