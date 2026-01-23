# 🚀 The Ultimate Developer Environment (Linux & macOS)

A high-performance, super-efficient development machine configuration designed for **Rust**, **Python**, and **AI** Engineering.

> **Status**: Verified on Zorin OS (Linux) and T2 Mac Hardware.
> **Philosophy**: Performance first, beautiful UI second, zero bloat third.

## 🌟 Key Features

### 🛠️ Core Infrastructure
- **Shell**: Instant-load `zsh` with `starship` prompt.
- **Package Management**:
  - `rustup` (Rust)
  - `fnm` (Node.js v22+)
  - `uv` (Ultra-fast Python)
- **Navigation**: `zoxide` (smart cd), `yazi` (fast file manager), `fzf` (fuzzy finding everywhere).

### ⚡ Performance Tuning
- **Kernel**: Optimized `sysctl.conf` for low latency and high network throughput.
- **Memory**: `zram` enabled for efficient memory compression.
- **Builds**: `mold` linker + `sccache` for 3x-10x faster Rust compiles.

### 🧠 Neovim IDE (v0.12 Nightly)
A VS Code rival running in the terminal:
- **Modular Config**: `lazy.nvim` based.
- **AI Integration**: Copilot + **CopilotChat** (Sidebar).
- **Productivity**:
  - **Problems Panel** (`trouble.nvim`)
  - **Search/Replace** (`spectre`)
  - **Auto-Pairs** & **Session Restore**
- **Language Support**: Rust (`rustaceanvim`), Python (`basedpyright`), Markdown.

### 🖥️ Desktop & Browser
- **GNOME**: Bloatware removed, performance extensions enabled.
- **Chrome**: Managed policies for memory/energy saving and privacy.

---

## 🚀 Quick Start

### 1. Installation

```bash
# Clone the repository
git clone https://github.com/sebastienrousseau/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the installer (Idempotent)
./install.sh
```

### 2. Neovim Setup

```bash
# Update to Nightly (Required for plugins)
./scripts/upgrade_neovim_nightly.sh

# Install Dependencies (for Debian/Ubuntu-based systems)
sudo apt install build-essential ripgrep fd-find unzip

# Launch
nvim
```

---

## 📂 Documentation

- [🗺️ Project Roadmap](docs/roadmap.md): The journey from stock OS to power user.
- [📝 Neovim Guide](docs/neovim_ide_guide.md): Keyboard shortcuts, plugin details, and AI usage.

---

## 🔧 Tuning Details

### System (`etc/sysctl.d/99-tuning.conf`)
- Increased file descriptors for large monorepos.
- TCP Fast Open and BBR congestion control enabled.
- **To apply:** `sudo cp etc/sysctl.d/99-tuning.conf /etc/sysctl.d/`

### Browser (`etc/opt/chrome/policies/managed`)
- Enforced "Memory Saver" mode.
- Blocked third-party cookies by default.
- Pre-installed dev extensions (uBlock, React DevTools, etc.).
- **To apply:** `sudo cp -r etc/opt/chrome/policies/managed /etc/opt/chrome/policies/`

---

## 🤝 Contributing

We welcome contributions! Please see the [contributing guidelines](.github/CONTRIBUTING.md) for more information.

This setup is designed for **PR #62**.
Please verify all scripts in a VM before running on production hardware.
