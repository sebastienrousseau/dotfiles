# Operational Guide

This document outlines the standard workflows to **Maintain**, **Update**, and **Operate** your dotfiles environment across all supported platforms.

---

## 🏗️ Platform-Specific Operations

### 🍎 macOS
**Primary Manager**: `Homebrew`

- **Update System**:
  ```bash
  # Updates Dotfiles AND Homebrew packages
  chezmoi update
  ```
  *Behind the scenes, this runs `brew bundle install` to match the `Brewfile.lock.json`.*

- **Troubleshooting**:
  - **Permission Issues**: `sudo chown -R $(whoami) $(brew --prefix)/*`
  - **Drift**: Run `brew bundle cleanup` to remove unmanaged packages.

### 🐧 Linux (Debian, Ubuntu, ZorinOS, Kali)
**Primary Manager**: `apt-get` / `snap`

- **Update System**:
  ```bash
  # 1. Update OS packages
  sudo apt update && sudo apt upgrade -y
  
  # 2. Update Dotfiles
  chezmoi update
  ```
  *Note: `chezmoi` on Linux focuses on configuration. Package updates are often best handled by the OS package manager to avoid `sudo` conflicts.*

- **Troubleshooting**:
  - **Font Issues**: If icons are missing, run `./install/provision/run_onchange_50-install-fonts.sh` manually.
  - **ZorinOS/Gnome**: Custom keybindings may need `dconf load` if not applied automatically.

### 🪟 Windows (WSL2)
**Primary Manager**: `apt-get` (inside WSL)

- **Update System**: Same as **Linux**.

- **WSL Specifics**:
  - **Access Windows Files**: Windows drives are mounted at `/mnt/c/`.
  - **Clipboard**: The setup configures `win32yank.exe` automatically for clipboard sharing.
  - **Performance**: We recommend keeping project files inside the Linux filesystem (`~/projects`), NOT in `/mnt/c/`, for 100x better IO performance.

---

## 🔄 Common Workflows

### Applying Changes
After editing any config file:
```bash
dot apply
```
*Triggers: `dot_zshrc` reload, audit logging.*

### Rolling Back
If an update breaks your setup:
```bash
cd ~/.dotfiles
git reset --hard HEAD@{1}  # Go back 1 operation
chezmoi apply
```

### Debugging
If something feels slow or broken:

1. **Check Health**:
   ```bash
   dot doctor
   ```
2. **Verbose Mode**:
   ```bash
   DOTFILES_DEBUG=1 dot apply
   ```

---

## 🛠️ Tool-Specific Guides

### 🎨 Visual Themes (Optional)
- **Wallpaper rotation**:
  ```bash
  ~/.dotfiles/scripts/theme/wallpaper-rotate.sh --interval 300
  ```
- **Cursor theme (Linux)**:
  ```bash
  DOTFILES_CURSOR_THEME=Papirus ~/.dotfiles/scripts/theme/install-cursors.sh
  ```
- **File icons (Linux/macOS)**:
  ```bash
  DOTFILES_ICON_THEME=Papirus ~/.dotfiles/scripts/theme/install-file-icons.sh
  ```
- **Lock icon (Linux)**:
  ```bash
  DOTFILES_LOCK_ICON=~/.config/dotfiles/lock/icon.png ~/.dotfiles/scripts/theme/install-lock-icon.sh
  ```
- **GRUB theme (Linux)**:
  ```bash
  sudo ~/.dotfiles/scripts/theme/install-grub-theme.sh --apply
  ```
- **Boot logo (Linux)**:
  ```bash
  sudo ~/.dotfiles/scripts/theme/install-boot-logo.sh --apply
  ```

### 📦 Atuin (History Sync)
- **Login**: `atuin login`
- **Sync**: `atuin sync`
- **Search**: `Ctrl-r` (Global history search)

### 🚀 Zoxide (Smart CD)
- **Jump**: `z project` matches `~/dev/project`
- **Query**: `zi` (Interactive selection)

### 🌳 Yazi (File Manager)
- **Open**: Type `y`
- **Preview**: Spacebar to preview files
- **Quit**: `q`

---

## 🔐 Security Policy
- **GPG/SSH**: All commits are SSH signed.
- **Audit Log**: Review `~/.dotfiles_audit.log` for a timeline of all changes applied to your system.
