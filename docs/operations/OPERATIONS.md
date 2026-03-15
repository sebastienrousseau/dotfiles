# Operations

Core workflows for keeping your dotfiles running across platforms.

---

## Platforms

### macOS

**Primary manager**: `Homebrew`

- **Update**:
  ```bash
  chezmoi update
  ```
  This runs `brew bundle install` behind the scenes to match `Brewfile.lock.json`.
- **Permission issues**: `sudo chown -R $(whoami) $(brew --prefix)/*`
- **Drift**: Run `brew bundle cleanup` to remove unmanaged packages.

### Linux (Debian, Ubuntu, Kali)

**Primary manager**: `apt-get` / `snap`

- **Update**:
  ```bash
  sudo apt update && sudo apt upgrade -y
  chezmoi update
  ```
  On Linux, `chezmoi` focuses on configuration. Package updates work best through the OS package manager to avoid `sudo` conflicts.
- **Font issues**: If icons are missing, run `./install/provision/run_onchange_50-install-fonts.sh` manually.

### Windows (WSL2)

**Primary manager**: `apt-get` (inside WSL)

- **Update**: Same as Linux.
- **Clipboard**: Dotfiles configures `win32yank.exe` automatically for clipboard sharing.
- **Performance**: Keep project files inside the Linux filesystem (`~/projects`), not in `/mnt/c/`, for dramatically better IO.

---

## Workflows

### Apply changes

After editing any config file:

```bash
dot apply
```

Triggers `dot_zshrc` reload and audit logging.

### Upgrade-safe apply (recommended)

```bash
git pull
DOTFILES_NONINTERACTIVE=1 dot apply --force
dot doctor
```

`dot apply` includes post-apply checks that:
- Remove stale read-only zsh cache files (`~/.config/shell/*.zwc`, `~/.config/zsh/**/*.zwc`)
- Validate that `dot` resolves to `~/.local/bin/dot` in a fresh login shell

Finish by reloading your session (`exec zsh`) or restarting the terminal.

### Async updates

Run updates in the background; you'll get a status banner on the next shell launch:

```bash
dot update --async
```

### Roll back

If an update breaks your setup:

```bash
cd ~/.dotfiles
git reset --hard HEAD@{1}
chezmoi apply
```

### Offline / air-gapped mode

```bash
# 1. On a connected machine, bundle your setup:
dot bundle ~/Downloads

# 2. Transfer the archive to the offline machine, then:
tar --zstd -xf dotfiles_offline_bundle_*.tar.zst -P
cd ~/.dotfiles
./install.sh --force
```

### Pre-warm caches

Regenerate all tool caches to eliminate shell startup latency:

```bash
dot prewarm
```

### Debug

If something's slow or broken:

1. **Check health**:
   ```bash
   dot doctor
   dot health --fix
   ```
2. **Smoke test**:
   ```bash
   dot smoke-test
   ```
3. **Scorecard**:
   ```bash
   dot scorecard
   ```
4. **Chaos testing (self-healing)**:
   ```bash
   dot chaos --force
   dot heal
   ```
5. **Startup profiling**:
   ```bash
   dot perf --profile
   ```
6. **Post-merge verification**:
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

Destructive aliases are disabled by default. Enable only when needed:

```bash
export DOTFILES_ENABLE_DANGEROUS_ALIASES=1
```

### Tiered alias loading

Core aliases load eagerly. Ecosystem aliases are lazy-loaded and can be filtered:

```bash
export DOTFILES_ALIAS_ECOSYSTEMS=python,node
```

Valid ecosystem tags: `python`, `node`, `rust`, `network`, `legacy`.
