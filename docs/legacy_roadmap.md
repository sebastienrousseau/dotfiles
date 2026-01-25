# The Ultimate Developer Environment Roadmap

This roadmap outlines the path to a high-performance, super-efficient development machine designed for Rust, Python, and AI on Linux (Zorin OS / T2 Mac hardware).

## Phase 1: Foundation (Completed)
- **Core Shell**: Zsh + Oh My Zsh.
- **Modern Prompt**: Starship (hooked & active).
- **Language Managers**: `rustup` (Rust) and `fnm` (Node.js).
- **Ultra-Fast Python**: `uv` installed.
- **Basic Modern Tools**: `eza` (ls), `bat` (cat), `fd` (find), `ripgrep` (grep).
- **Git Enhancements**: `lazygit` (TUI) and `delta` (Diffs).
- **Multiplexer**: `zellij` installed.
- **AI**: `ollama` installed locally.
- **Security**: Firewall (`ufw`) enabled.

---

## Phase 2: Speed & Navigation (Completed)
Focus: Reduce friction in filesystem navigation and build times.

### 1. Navigation
- [x] **Zoxide**: Smarter `cd` command that learns your habits (`z directory`).
- [x] **FZF**: Command-line fuzzy finder. Essential for search history, files, and replacing standard completion.
- [x] **Yazi**: Blazing fast terminal file manager (Rust-based).

### 2. Rust Optimization
- [x] **Mold**: Use the `mold` linker to speed up Rust compile times by 3x-10x.
- [x] **Sccache**: Shared compilation cache to speed up recompilations across projects.
- [x] **Bacon**: Background rust compiler that gives instant feedback on errors.

### 3. Python Optimization
- [x] **Ruff**: Extremely fast Python linter and formatter (replace flake8/black).
- [x] **Global Config**: Set `uv` to use system Python or managed Python preferences.

### 4. Code Search
- [x] **Ripgrep-all (rga)**: Search inside PDFs, E-Books, zip files, etc.

---

## Phase 3: AI Power User (Completed)
Focus: Integrate AI deeply into the workflow.

- [x] **Fabric**: Open-source framework for augmenting humans using AI (installed via `cmd` path).
- [x] **Open WebUI**: A beautiful web interface for `ollama` (requires Docker).
- [x] **GitHub Copilot CLI**: Integrate AI assistance directly into the terminal commands.
- [x] **Local RAG**: Setup tools to chat with your own documents locally (Open WebUI).

---

## Phase 4: System Tuning & Hardening (Completed)
Focus: Squeeze every ounce of performance and security from the hardware.

- [x] **Kernel Tuning**: Increase file descriptor limits and optimize TCP stack for lower latency.
- [x] **Swap Optimization**: Configure `zram` for memory compression (improves performance on 16GB RAM).
- [x] **Flatpak Overrides**: Secure Flatpak permissions using `Flatseal`.
- [x] **Automated Updates**: Configure `unattended-upgrades` for security patches.

---

## Phase 5: Final Polish (Completed)
- [x] **Global UV Config**: Created `~/.config/uv/uv.toml` for managed python perference.
- [x] **Roadmap Completion**: Verified all items are 100% complete.

---

## Maintenance & Updates
- **Update System**: `sudo apt update && sudo apt upgrade`
- **Update Rust**: `rustup update`
- **Update Node**: `fnm install --lts`
- **Update UV**: `uv self update`
- **Update Firmware**: `fwupdmgr get-updates`

---

## Phase 6: Desktop Environment (Completed)
Focus: Clean, bloat-free, and supercharged GNOME/Zorin experience.

- [x] **Bloatware Removal**: Removed games (`aisleriot`, `mines`, etc.) and media apps (`rhythmbox`, `totem`).
- [x] **Menu Cleanup**: Created `hide_menu_entries.sh` to deduplicate and hide unwanted entries.
- [x] **GNOME Extensions**: Installed productivity boosters via `gnome-extensions-cli`:
    - [x] `Clipboard Indicator`: History management.
    - [x] `Caffeine`: Prevent auto-suspend.
    - [x] `Impatience`: Speed up animations.
    - [x] `Vitals`: System monitoring in top bar.
- [x] **Memory Tuning**: Optimize GNOME Shell performance.

---

## Phase 7: Browser Optimization (Completed)
Focus: Chrome tuned for development and memory efficiency.

- [x] **Settings**: Enable "Memory Saver" and "Energy Saver" via Managed Policies.
- [x] **Extensions**: Automated installation of developer stack (uBlock, JSON Viewer, React DevTools, Vimium, Refined GitHub).
- [x] **Profile Separation**: Separate Personal and Work profiles (Manual setup recommendation).

---

## Phase 8: Neovim IDE (Completed)
Focus: Building a terminal-based IDE that rivals VS Code for Rust, Python, and AI.

- [x] **Latest Version**: Installed Neovim v0.12.0-dev (Nightly) to resolve plugin stability issues.
- [x] **Plugin Manager**: Setup `lazy.nvim` with modular config (Restored from **PR #62**).
- [x] **Core Plugins**:
    - [x] `Telescope`: Fuzzy finding.
    - [x] `Treesitter`: Syntax highlighting.
    - [x] `Harpoon`: Fast file switching.
    - [x] `Neo-tree`: File explorer.
- [x] **UI/UX Menus**: Added `dressing.nvim` and `telescope-ui-select.nvim` for modern, searchable selection lists and floating inputs.
- [x] **LSP & Autocomplete**:
    - [x] `Mason`: Managing LSPs (rust-analyzer, pyright, ruff).
    - [x] `Cmp`: Autocompletion engine.
- [x] **Language Specifics**:
    - [x] **Rust**: `rustaceanvim` configured.
    - [x] **Python**: `pyright` + `ruff`.
- [x] **AI Integration**:
    - [x] `Copilot.lua`: Enabled (needs `:Copilot auth`).
    - [x] `CopilotChat.nvim`: Sidebar chat (VS Code style).
    - [ ] `Avante.nvim`: Skipped (Removed due to complexity/instability).
- [x] **VS Code Parity Pack**:
    - [x] `Trouble`: Problems panel.
    - [x] `Spectre`: Search/Replace.
    - [x] `Autopairs`: Auto-close brackets.
    - [x] `Todo-Comments`: TODO/FIXME highlighting.
    - [x] `Persistence`: Session management.

---

## Phase 9: Repository Polish & PR #62 (In Progress)
Focus: Finalize the `dotfiles` repository for public consumption and sync the local "Gold Standard" environment.

- [x] **Repository Sync**:
    - [x] Clone official repo to `~/dotfiles`.
    - [ ] Sync validated configuration (Neovim, scripts, tuning) into repository.
- [ ] **Documentation Update**:
    - [ ] Refactor `README.md` for the modern architecture.
    - [ ] Add "Easy Setup" and "Troubleshooting" guides.
- [ ] **Final PR Submission**:
    - [ ] Verify clean diff against original PR #62.
    - [ ] Push updates to PR #62 branch.



