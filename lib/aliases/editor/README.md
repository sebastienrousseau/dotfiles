<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂

This code provides a comprehensive set of command aliases for editing files using the editor configured in your environment. It works in conjunction with the editor configuration script (`editor.sh`) which automatically selects the best available editor on your system.

### Supported Editors

The following editors are supported with specialized aliases:

- **Neovim** - Modern, enhanced version of Vim
- **Visual Studio Code** - Feature-rich code editor with extensions
- **Vim** - Highly configurable text editor
- **Nano** - Simple and user-friendly terminal editor
- **Emacs** - Extensible, customizable text editor
- **Sublime Text** - Sophisticated text editor for code
- **Atom** - Hackable text editor for the 21st century

### Common Editor Aliases

These universal aliases work with any editor set by `editor.sh`:

- `e` - Quick edit command
- `edit` - Standard edit command
- `editor` - Full editor command
- `mate` - TextMate-style command
- `n` - Short edit alias
- `v` - Vim-like edit alias

### Editor-Specific Aliases

Depending on which editor is selected by `editor.sh`, additional specialized aliases are automatically available:

#### Neovim Aliases

- `vi`, `vim` - Redirected to Neovim when it's the primary editor
- `nvimrc` - Edit Neovim Vimscript configuration file
- `nvimlua` - Edit Neovim Lua configuration file
- `nvimconf` - Open Neovim configuration directory

#### VS Code Aliases

- `vsc` - Shorthand for VS Code
- `vsca` - Add folder to current window
- `vscd` - Compare two files
- `vscn` - Open new window
- `vscr` - Reuse window when opening files
- `vscu` - Open with custom user data directory
- `vsced` - Open with custom extensions directory
- `vscex` - Install VS Code extension
- `vsclist` - List installed extensions

#### Vim Aliases

- `vi` - Redirected to Vim when it's the primary editor
- `vimrc` - Edit Vim configuration file
- `vimconf` - Open Vim configuration directory

#### Nano Aliases

- `nanorc` - Edit Nano configuration file
- `ne` - Enhanced Nano with line numbers and smooth scrolling

#### Emacs Aliases

- `em` - Shorthand for Emacs
- `emacs-nw` - Run Emacs in terminal mode
- `emacsc` - Launch Emacs client
- `emacsrc` - Edit Emacs configuration file
- `et` - Quick terminal-based Emacs

#### Sublime Text Aliases

- `st` - Launch Sublime Text
- `stt` - Open current directory in Sublime Text
- `stn` - Open in new Sublime Text window

#### Atom Aliases

- `a` - Launch Atom
- `at` - Open current directory in Atom
- `an` - Open in new Atom window

### Quick Configuration Editing

The script provides the `editrc` function to quickly edit common configuration files:

```bash
editrc bash     # Edit ~/.bashrc
editrc zsh      # Edit ~/.zshrc
editrc vim      # Edit ~/.vimrc
editrc nvim     # Edit Neovim init file
editrc tmux     # Edit ~/.tmux.conf
editrc git      # Edit ~/.gitconfig
editrc ssh      # Edit ~/.ssh/config
editrc alias    # Edit ~/.dotfiles/aliases
editrc dotfiles # Edit ~/.dotfiles
```

### Integration with editor.sh

These aliases work in harmony with the `editor.sh` script which:

1. Automatically detects available editors on your system
2. Sets appropriate environment variables (`EDITOR`, `VISUAL`, `GIT_EDITOR`, etc.)
3. Configures editor-specific settings
4. Provides intelligent fallbacks

The aliases in this file are designed to provide convenient shortcuts based on the editor that was selected by the detection process.

### Usage Examples

```bash
# Quick edit a file using the default editor
e myfile.txt

# Edit configuration files directly
nvimrc    # When using Neovim (vimscript)
nvimlua   # When using Neovim (lua)
vimrc     # When using Vim
nanorc    # When using Nano

# Use VS Code to open a folder in a new window
vscn ~/projects/my-project

# Use enhanced nano with line numbers
ne config.txt

# Edit specific configuration files
editrc git    # Edit git configuration
editrc bash   # Edit bash configuration
```

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
