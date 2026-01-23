# Phase 8: Neovim IDE Walkthrough

## Completed Objectives

### 1. Installation (v0.10.3)
- **Action**: Installed latest stable Neovim to `/opt/nvim-linux64` and linked to `~/.local/bin/nvim`.
- **Verify**: Run `nvim --version` (should be v0.10.3+).

### 2. Configuration (Restored & Enhanced)
- **Action**: Restored your original modular configuration from `~/.config/nvim.bak`.
- **Enhancement**: Added `avante.lua` to `lua/plugins/` (removed later).
- **UI Upgrade**: Added `dressing.nvim` and `telescope-ui-select` for premium floating menus.
- **Compatibility**: Upgraded Neovim to **Nightly (v0.11)** to support latest plugin versions.

### 3. Core Plugins (Restored)
- **Originals**: `snacks.nvim`, `gitsigns`, `neo-tree`, `venv-selector`, etc. are all preserved.
- **New**: `Avante.nvim` (AI Sidebar) added seamlessly.

### 4. Language Support (LSP)
- **Rust**: `rustaceanvim` (Auto-configured for Rust).
- **Python**: `pyright` + `ruff` (Installed via Mason).
- **General**: `mason.nvim` manages LSP servers. They install on first launch.

### 5. AI Integration
- **Copilot**: `copilot.lua` (Enabled). Run `:Copilot auth` to sign in.
- **Copilot Chat**: AI sidebar (`<leader>cc`). Replaces Avante.

### 6. VS Code Parity (New)
- **Problem Panel**: `trouble.nvim` (`<leader>xx`).
- **Search & Replace**: `nvim-spectre` (`<leader>S`).
- **Auto-Pairs**: Automatically closes brackets.
- **TODOs**: Highlights `TODO` and `FIXME`.
- **Session**: Auto-restores your last session.

## New Keybinds Cheat Sheet
| Key | Action |
| --- | --- |
| `<Space>ff` | Find Files |
| `<Space>fg` | Grep (Search) text |
| `<Space>e` | Toggle File Explorer |
| `<Space>a` | Add file to Harpoon |
| `<Ctrl>e` | Open Harpoon menu |
| `gd` | Go to Definition |
| `gr` | Go to References |
