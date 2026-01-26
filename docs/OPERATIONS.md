# Discover operations

This guide covers the core workflows to keep your dotfiles running well across platforms.

---

## Platforms

### macOS
**Primary manager**: `Homebrew`

- **Update system**:
  ```bash
  # Updates Dotfiles AND Homebrew packages
  chezmoi update
  ```
  *Behind the scenes, this runs `brew bundle install` to match the `Brewfile.lock.json`.*

- **Troubleshooting**:
  - **Permission issues**: `sudo chown -R $(whoami) $(brew --prefix)/*`
  - **Drift**: Run `brew bundle cleanup` to remove unmanaged packages.

### Linux (Debian, Ubuntu, ZorinOS, Kali)
**Primary manager**: `apt-get` / `snap`

- **Update system**:
  ```bash
  # 1. Update OS packages
  sudo apt update && sudo apt upgrade -y
  
  # 2. Update Dotfiles
  chezmoi update
  ```
  *Note: `chezmoi` on Linux focuses on configuration. Package updates are often best handled by the OS package manager to avoid `sudo` conflicts.*

- **Troubleshooting**:
  - **Font issues**: If icons are missing, run `./install/provision/run_onchange_50-install-fonts.sh` manually.
  - **ZorinOS/GNOME**: Custom keybindings may require `dconf load` if Chezmoi does not apply them automatically.

### Windows (WSL2)
**Primary manager**: `apt-get` (inside WSL)

- **Update system**: Same as **Linux**.

- **WSL specifics**:
  - **Access Windows files**: WSL mounts Windows drives at `/mnt/c/`.
  - **Clipboard**: The setup configures `win32yank.exe` automatically for clipboard sharing.
  - **Performance**: Keep project files inside the Linux filesystem (`~/projects`), NOT in `/mnt/c/`, for 100x better IO performance.

---

## Workflows

### Apply changes
After editing any config file:
```bash
dot apply
```
*Triggers: `dot_zshrc` reload, audit logging.*

### Roll back
If an update breaks your setup, revert:
```bash
cd ~/.dotfiles
git reset --hard HEAD@{1}  # Go back 1 operation
chezmoi apply
```

### Debug
If something runs slow or appears broken:

1. **Check health**:
   ```bash
   dot doctor
   ```
2. **Verbose mode**:
   ```bash
   DOTFILES_DEBUG=1 dot apply
   ```

---

## Tools

### Make it yours
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

### Atuin
- **Login**: `atuin login`
- **Sync**: `atuin sync`
- **Search**: `Ctrl-r` (Global history search)

### Zoxide
- **Jump**: `z project` matches `~/dev/project`
- **Query**: `zi` (Interactive selection)

### Yazi
- **Open**: Type `y`
- **Preview**: Spacebar to preview files
- **Quit**: `q`

---

## Security policy
- **GPG/SSH**: All commits use SSH signing.
- **Audit log**: Review `~/.local/share/dotfiles.log` for a timeline of all changes the system applied.
