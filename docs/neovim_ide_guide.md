# Neovim IDE Guide

## Features

### 1. Modern Core
- **Installation**: Uses Neovim Nightly (v0.11+) for the latest features and plugin compatibility.
- **Configuration**: A modular and lazy-loaded configuration based on `lazy.nvim`.
- **UI**: A beautiful and functional UI with a dashboard, status line, buffer line, and file explorer.
- **LSP**: Full LSP support for diagnostics, code actions, and more, managed by `mason.nvim`.

### 2. Language Support
- **Rust**: Out-of-the-box support for Rust development with `rustaceanvim`.
- **Python**: Full support for Python development with `basedpyright`, `ruff`, and `venv-selector`.
- **Web**: Support for web development with `prettier` and `eslint`.

### 3. AI Integration
- **Copilot**: `copilot.lua` for code completion. Run `:Copilot auth` to sign in.
- **Copilot Chat**: AI sidebar for asking questions and getting help (`<leader>cc`).

### 4. VS Code Parity
- **Problem Panel**: `trouble.nvim` for a VS Code-like problems panel (`<leader>xx`).
- **Search & Replace**: `nvim-spectre` for project-wide search and replace (`<leader>S`).
- **Auto-Pairs**: Automatically closes brackets and pairs.
- **TODOs**: Highlights `TODO` and `FIXME` comments.
- **Session**: Auto-restores your last session.

## Keybinds Cheat Sheet
| Key | Action |
| --- | --- |
| `<Space>ff` | Find Files |
| `<Space>fg` | Grep (Search) text |
| `<Space>fb` | File browser |
| `<Space>fp` | Projects |
| `<Space>e` | Toggle File Explorer |
| `<Space>a` | Add file to Harpoon |
| `<Ctrl>e` | Open Harpoon menu |
| `gd` | Go to Definition |
| `gr` | Go to References |
| `<leader>ca` | Code actions |
| `<leader>cf` | Format code |
| `<leader>cr` | Rename symbol |
| `<leader>tt` | Toggle terminal |
| `<leader>tn` | Test nearest |
| `<leader>tf` | Test file |
| `<leader>ts` | Test suite |
| `<F5>` | Continue (Debug) |
| `<F10>` | Step over (Debug) |
| `<F11>` | Step into (Debug) |
| `<F12>` | Step out (Debug) |
| `<leader>cc` | Toggle Copilot Chat |
| `<leader>xx` | Toggle Diagnostics (Trouble) |
| `<leader>S` | Toggle Spectre (Search/Replace) |
