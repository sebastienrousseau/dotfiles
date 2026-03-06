# Operations

Core workflows for keeping your dotfiles running across platforms.

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
  > [!NOTE]
  > On Linux, `chezmoi` focuses on configuration. Package updates work best with the OS package manager to avoid `sudo` conflicts.

- **Troubleshooting**:
  - **Font issues**: If icons are missing, run `./install/provision/run_onchange_50-install-fonts.sh` manually.
  - **ZorinOS/GNOME**: Custom keybindings may require `dconf load` if Chezmoi does not apply them automatically.

### Windows (WSL2)
**Primary manager**: `apt-get` (inside WSL)

- **Update system**: Same as **Linux**.

- **WSL specifics**:
  - **Access Windows files**: WSL mounts Windows drives at `/mnt/c/`.
  - **Clipboard**: Dotfiles configures `win32yank.exe` automatically for clipboard sharing.
  - **Performance**: Keep project files inside the Linux filesystem (`~/projects`), NOT in `/mnt/c/`, for 100x better IO performance.

---

## Workflows

### Apply changes
After editing any config file:
```bash
dot apply
```
*Triggers: `dot_zshrc` reload, audit logging.*

### Upgrade-safe apply (recommended)
After updating to a new version:

```bash
git pull
DOTFILES_NONINTERACTIVE=1 dot apply --force
dot doctor
```

`dot apply` includes post-apply checks that:
- remove stale read-only zsh cache files (`~/.config/shell/*.zwc`, `~/.config/zsh/**/*.zwc`)
- validate that `dot` resolves to `~/.local/bin/dot` in a fresh login shell

Final step for the current terminal session:

```bash
exec zsh
```

If you prefer, restart the terminal instead.

### Async updates
Run updates in the background and get a status banner on the next shell launch:
```bash
dot update --async
```
### Roll back
If an update breaks your setup, revert:
```bash
cd ~/.dotfiles
git reset --hard HEAD@{1}  # Go back 1 operation
chezmoi apply
```

### Offline / Air-Gapped Mode
If you need to install dotfiles on a system without network access:
```bash
# 1. On a connected machine, bundle your setup:
dot bundle ~/Downloads

# 2. Transfer the archive to the offline machine, then:
tar --zstd -xf dotfiles_offline_bundle_*.tar.zst -P
cd ~/.dotfiles
./install.sh --force
```

### Pre-warm Caches
To eliminate shell startup latency by instantly regenerating all tool caches:
```bash
dot prewarm
```

### Debug
If something runs slow or appears broken:

1. **Check health**:
   ```bash
   dot doctor
   ```
   ```bash
   dot health --fix
   ```
2. **Smoke Test**:
   ```bash
   dot smoke-test
   ```
3. **Scorecard**:
   ```bash
   dot scorecard
   ```
4. **Chaos Testing (Self-Healing Verification)**:
   ```bash
   dot chaos --force
   dot heal
   ```
5. **Startup profiling**:
   ```bash
   dot perf --profile
   ```
6. **Run post-merge verification**:
   ```bash
   dot verify
   ```
7. **Inspect alias behavior**:
   ```bash
   dot aliases list
   dot aliases why dprune
   DOTFILES_ALIAS_POLICY=strict bash ~/.dotfiles/scripts/diagnostics/alias-governance.sh
   ```
8. **Verbose mode**:
   ```bash
   DOTFILES_DEBUG=1 dot apply
   ```

### Safety flags
- Destructive aliases are disabled by default. Enable only when needed:
  ```bash
  export DOTFILES_ENABLE_DANGEROUS_ALIASES=1
  ```

### Tiered alias loading
- Core aliases are loaded eagerly.
- Ecosystem aliases are lazy-loaded and can be filtered:
  ```bash
  export DOTFILES_ALIAS_ECOSYSTEMS=python,node
  ```
- Valid ecosystem tags: `python,node,rust,network,legacy`.

---

## Tools

### Customization
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

## Security

- **GPG/SSH** — all commits use SSH signing.
- **Audit log** — review `~/.local/share/dotfiles.log` for a timeline of changes.
