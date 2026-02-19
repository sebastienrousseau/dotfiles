# WSL2 & Nix Integration Troubleshooting Guide

### Metadata
- **Type:** How-To Guide / Reference
- **Audience:** Intermediate / Advanced
- **Prerequisites:** Basic familiarity with command line, WSL2, and Nix package manager

### Content

A comprehensive troubleshooting guide for WSL2 edge cases, Nix integration issues, and recovery procedures for failed installations.

## Table of Contents

- [WSL2 Edge Cases](#wsl2-edge-cases)
- [Nix Integration Issues](#nix-integration-issues)
- [Recovery Procedures](#recovery-procedures)
- [Performance Optimization](#performance-optimization)
- [Cross-Platform Migration](#cross-platform-migration)
- [Emergency Recovery](#emergency-recovery)

---

## WSL2 Edge Cases

### Filesystem Issues

#### Problem: Symlinks fail to work between Windows and WSL2
```bash
# Check if symlinks are enabled
ls -la ~/.dotfiles/
# Look for broken symlinks (red entries)
```

**Root Cause:** Windows filesystem doesn't support Unix symlinks by default.

**Solutions:**
1. **Enable Developer Mode** (Windows 10/11):
   ```powershell
   # Run in PowerShell as Administrator
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   ```

2. **Use WSL2 native filesystem**:
   ```bash
   # Move dotfiles to WSL2 filesystem
   cd /home/$USER
   git clone https://github.com/yourusername/dotfiles.git .dotfiles
   ```

3. **Configure Git for WSL2**:
   ```bash
   git config --global core.symlinks true
   git config --global core.autocrlf false
   ```

#### Problem: Slow filesystem performance on Windows drives
```bash
# Test filesystem performance
time ls -la /mnt/c/Users/
time ls -la ~/
```

**Solution:** Always work within WSL2 filesystem (`/home/`) for performance-critical operations.

#### Problem: Permission denied errors on mounted Windows drives
```bash
# Check mount options
mount | grep drvfs
```

**Solution:** Remount with proper permissions:
```bash
# Create /etc/wsl.conf
sudo tee /etc/wsl.conf > /dev/null <<EOF
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = false
EOF

# Restart WSL2 from Windows PowerShell
wsl --shutdown
```

### Networking Issues

#### Problem: DNS resolution fails in WSL2
```bash
# Test DNS resolution
nslookup github.com
ping github.com
```

**Solutions:**
1. **Reset WSL2 DNS**:
   ```bash
   sudo rm /etc/resolv.conf
   sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
   ```

2. **Configure permanent DNS**:
   ```bash
   sudo tee /etc/wsl.conf > /dev/null <<EOF
[network]
generateResolvConf = false
EOF

   sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
   ```

#### Problem: Port forwarding doesn't work
```bash
# Check if port is bound
netstat -tulpn | grep :3000
```

**Solution:** Use Windows port proxy:
```powershell
# Run in PowerShell as Administrator
netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=172.x.x.x
```

### Memory and Resource Issues

#### Problem: WSL2 consumes excessive memory
```bash
# Check WSL2 memory usage
cat /proc/meminfo | grep MemTotal
free -h
```

**Solution:** Limit WSL2 memory usage:
```ini
# Create %UserProfile%\.wslconfig
[wsl2]
memory=8GB
processors=4
swap=2GB
```

#### Problem: WSL2 doesn't release memory back to Windows
**Solution:** Compact WSL2 virtual disk:
```powershell
# Run in PowerShell as Administrator
wsl --shutdown
diskpart
# select vdisk file="C:\Users\%USERNAME%\AppData\Local\Packages\CanonicalGroupLimited.UbuntuonWindows_79rhkp1fndgsc\LocalState\ext4.vhdx"
# attach vdisk readonly
# compact vdisk
# detach vdisk
# exit
```

---

## Nix Integration Issues

### Installation Problems

#### Problem: Nix installation fails on WSL2
```bash
# Check if installation attempted
ls -la /nix/
which nix
```

**Solutions:**
1. **Use deterministic installer**:
   ```bash
   curl -L https://nixos.org/nix/install | sh -s -- --daemon
   ```

2. **Fix permissions after installation**:
   ```bash
   sudo chown -R $(whoami) /nix/var/nix/profiles/per-user/$(whoami)/
   sudo chmod -R 755 /nix/var/nix/profiles/per-user/$(whoami)/
   ```

3. **Enable systemd for Nix daemon** (WSL2 Ubuntu 22.04+):
   ```bash
   sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
   ```

#### Problem: Nix flakes not recognized
```bash
# Test flakes support
nix flake --help
```

**Solution:** Enable experimental features:
```bash
mkdir -p ~/.config/nix/
tee ~/.config/nix/nix.conf > /dev/null <<EOF
experimental-features = nix-command flakes
trusted-users = $(whoami)
EOF

# Or globally
sudo tee /etc/nix/nix.conf > /dev/null <<EOF
experimental-features = nix-command flakes
trusted-users = @wheel
EOF
```

#### Problem: SSL certificate errors during Nix operations
```bash
# Test Nix store access
nix ping-store
```

**Solutions:**
1. **Update CA certificates**:
   ```bash
   sudo apt update && sudo apt install ca-certificates
   ```

2. **Configure Nix with custom CA bundle**:
   ```bash
   export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
   echo 'export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' >> ~/.bashrc
   ```

### Flake and Profile Issues

#### Problem: Flake lock file conflicts
```bash
# Check flake lock status
cd ~/.dotfiles/nix/
nix flake check --impure
```

**Solution:** Update and rebuild lock file:
```bash
cd ~/.dotfiles/nix/
rm flake.lock
nix flake update
nix flake check
```

#### Problem: Nix profile conflicts with system packages
```bash
# List Nix profiles
nix profile list
# Check which packages are shadowing system ones
which -a git
```

**Solutions:**
1. **Remove conflicting profiles**:
   ```bash
   nix profile remove <profile-number>
   ```

2. **Use priority settings**:
   ```bash
   nix profile install nixpkgs#git --priority 10
   ```

3. **Create isolated development environments**:
   ```bash
   cd ~/.dotfiles/nix/
   nix develop
   ```

#### Problem: Nix store corruption
```bash
# Check store integrity
nix-store --verify --check-contents
```

**Solution:** Repair corrupted store:
```bash
# Stop Nix daemon
sudo systemctl stop nix-daemon

# Repair store
sudo nix-store --verify --check-contents --repair

# Restart daemon
sudo systemctl start nix-daemon
```

### Build and Cache Issues

#### Problem: Binary cache not working
```bash
# Test cache connectivity
nix ping-store --store https://cache.nixos.org
```

**Solution:** Configure trusted substituters:
```bash
sudo tee -a /etc/nix/nix.conf > /dev/null <<EOF
substituters = https://cache.nixos.org/ https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
EOF
```

#### Problem: Out of disk space during build
```bash
# Check Nix store size
du -sh /nix/store/
df -h /nix/
```

**Solution:** Clean up Nix store:
```bash
# Remove unused packages
nix-collect-garbage

# Deep cleanup (removes old generations)
nix-collect-garbage -d

# Optimize store (hard link identical files)
nix-store --optimise
```

---

## Recovery Procedures

### Complete System Recovery

#### Scenario: Dotfiles installation completely broken
```bash
# 1. Backup current state
cp ~/.zshrc ~/.zshrc.backup.$(date +%s)
cp ~/.bashrc ~/.bashrc.backup.$(date +%s)

# 2. Reset to minimal shell
export PATH=/usr/bin:/bin
unset ZDOTDIR

# 3. Clean chezmoi state
rm -rf ~/.local/share/chezmoi/
rm -rf ~/.config/chezmoi/

# 4. Reinstall from scratch
cd /tmp
curl -fsSL https://raw.githubusercontent.com/yourusername/dotfiles/main/install.sh | bash
```

#### Scenario: WSL2 completely broken
```powershell
# From Windows PowerShell as Administrator

# 1. Export current installation (backup)
wsl --export Ubuntu Ubuntu-backup.tar

# 2. Unregister broken installation
wsl --unregister Ubuntu

# 3. Reinstall from Microsoft Store or import backup
wsl --import Ubuntu C:\WSL\Ubuntu Ubuntu-backup.tar

# 4. Reinstall dotfiles
wsl -d Ubuntu -u root -- curl -fsSL https://raw.githubusercontent.com/yourusername/dotfiles/main/install.sh | bash
```

### Partial Recovery

#### Fix broken Nix installation
```bash
# 1. Remove broken Nix
sudo rm -rf /nix/
sudo userdel -r nix-daemon 2>/dev/null || true
sudo groupdel nixbld 2>/dev/null || true

# 2. Clean environment
unset NIX_PATH
unset NIX_PROFILES
unset NIX_SSL_CERT_FILE

# 3. Reinstall Nix
curl -L https://nixos.org/nix/install | sh

# 4. Restart shell and test
exec zsh
which nix
```

#### Fix broken shell configuration
```bash
# 1. Use emergency shell config
cat > ~/.zshrc.emergency <<'EOF'
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export SHELL=/bin/zsh
alias ll='ls -la'
alias la='ls -la'
PS1='%n@%m:%~$ '
EOF

# 2. Test emergency config
zsh -c 'source ~/.zshrc.emergency && echo "Emergency config works"'

# 3. Gradually restore
mv ~/.zshrc ~/.zshrc.broken
ln -s ~/.zshrc.emergency ~/.zshrc

# 4. Reinstall dotfiles piece by piece
cd ~/.dotfiles
chezmoi init --force
chezmoi apply --dry-run
chezmoi apply
```

### Data Recovery

#### Recover encrypted secrets
```bash
# 1. Check if key file exists
ls -la ~/.config/chezmoi/key.txt

# 2. If missing, try to recover from backup locations
find / -name "key.txt" -type f 2>/dev/null
find /mnt/c/ -name "*.key" -type f 2>/dev/null

# 3. Test key validity
age -d -i ~/.config/chezmoi/key.txt ~/.local/share/chezmoi/encrypted_file.age

# 4. If key is lost, regenerate encrypted files
chezmoi execute-template --init --force
```

#### Recover Git configuration
```bash
# 1. Check current git config
git config --list --show-origin

# 2. Backup current config
cp ~/.gitconfig ~/.gitconfig.backup.$(date +%s)

# 3. Restore from dotfiles
chezmoi apply --include='**/dot_gitconfig*'

# 4. Verify critical settings
git config --get user.name
git config --get user.email
git config --get core.editor
```

---

## Performance Optimization

### WSL2 Performance Tuning

#### Optimize filesystem performance
```bash
# 1. Move frequently accessed files to WSL2 filesystem
mkdir -p /home/$USER/workspace
ln -s /home/$USER/workspace ~/workspace

# 2. Configure Git for performance
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# 3. Use native WSL2 paths in tools
export BROWSER="/mnt/c/Program Files/Mozilla Firefox/firefox.exe"
export EDITOR="nvim"
```

#### Reduce memory usage
```bash
# 1. Limit shell history
echo 'HISTSIZE=1000' >> ~/.zshrc
echo 'SAVEHIST=1000' >> ~/.zshrc

# 2. Disable unnecessary services
sudo systemctl disable apache2 2>/dev/null || true
sudo systemctl disable mysql 2>/dev/null || true

# 3. Configure swap usage
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
```

### Nix Performance Tuning

#### Optimize Nix builds
```bash
# Configure build settings
sudo tee -a /etc/nix/nix.conf > /dev/null <<EOF
max-jobs = auto
cores = 0
sandbox = true
substituters = https://cache.nixos.org/ https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
```

#### Enable build caching
```bash
# Install and configure cachix
nix profile install nixpkgs#cachix
cachix use nix-community

# Add to shell config
echo 'eval "$(cachix completion bash)"' >> ~/.bashrc
```

---

## Cross-Platform Migration

### Moving from macOS to WSL2

#### Environment differences checklist
```bash
# 1. Check path differences
echo $PATH | tr ':' '\n' | sort

# 2. Check shell differences
echo $SHELL
zsh --version

# 3. Check package managers
which brew 2>/dev/null && echo "Homebrew found"
which apt 2>/dev/null && echo "APT found"
which nix 2>/dev/null && echo "Nix found"
```

#### Migration procedure
```bash
# 1. Export current configuration
cd ~/.dotfiles
chezmoi archive --format=tar | gzip > dotfiles-backup.tar.gz

# 2. Transfer to WSL2 (from Windows side)
# Copy dotfiles-backup.tar.gz to Windows, then:
# cp /mnt/c/Users/username/Downloads/dotfiles-backup.tar.gz ./

# 3. Import on WSL2
tar -xzf dotfiles-backup.tar.gz
cd ~/.dotfiles
git remote update
git pull origin main

# 4. Platform-specific adjustments
chezmoi apply --dry-run
chezmoi apply
```

### Moving from Linux to WSL2

#### Handle systemd differences
```bash
# Check systemd status
systemctl is-system-running 2>/dev/null || echo "systemd not available"

# Alternative service management for WSL2
sudo service ssh start  # Instead of systemctl start ssh
```

#### Network configuration migration
```bash
# 1. Export network settings from source system
ip route show > network-config.txt
cat /etc/resolv.conf >> network-config.txt

# 2. Adapt for WSL2
# (WSL2 handles most networking automatically)
```

---

## Emergency Recovery

### Emergency Shell Access

#### If shell is completely broken
```bash
# 1. Access via different shell
/bin/bash --noprofile --norc

# 2. Or use emergency profile
export PATH=/usr/bin:/bin
export PS1="EMERGENCY $ "
export SHELL=/bin/bash

# 3. Fix basic functionality
alias ls='ls --color=auto'
alias ll='ls -la'
```

#### If WSL2 won't start
```powershell
# From Windows PowerShell as Administrator

# 1. Check WSL2 status
wsl --status

# 2. Restart WSL2 service
net stop LxssManager
net start LxssManager

# 3. If that fails, restart Docker Desktop (if installed)
# Then restart WSL2

# 4. Last resort: restart Windows
```

### Emergency Contacts and Resources

#### Diagnostic commands for support requests
```bash
# System information
cat /etc/os-release
uname -a
wsl.exe --version 2>/dev/null || echo "Not in WSL2"

# Nix information
nix --version 2>/dev/null || echo "Nix not installed"
nix-env --version 2>/dev/null || echo "nix-env not available"

# Dotfiles information
cd ~/.dotfiles && git log --oneline -5
chezmoi --version 2>/dev/null || echo "Chezmoi not installed"

# Generate diagnostic report
cat > ~/diagnostic-report.txt <<EOF
Date: $(date)
User: $(whoami)
Shell: $SHELL
OS: $(cat /etc/os-release | grep PRETTY_NAME)
Kernel: $(uname -r)
WSL Version: $(wsl.exe --version 2>/dev/null || echo "Not in WSL2")
Nix Version: $(nix --version 2>/dev/null || echo "Not installed")
Chezmoi Version: $(chezmoi --version 2>/dev/null || echo "Not installed")

Recent Git Commits:
$(cd ~/.dotfiles && git log --oneline -5 2>/dev/null || echo "Git not available")

Current PATH:
$(echo $PATH | tr ':' '\n' | nl)

Nix Profiles:
$(nix profile list 2>/dev/null || echo "Nix profiles not available")

WSL Mount Points:
$(mount | grep drvfs || echo "No Windows mounts")
EOF

echo "Diagnostic report saved to ~/diagnostic-report.txt"
```

#### Support channels
- GitHub Issues: [Repository Issues](https://github.com/yourusername/dotfiles/issues)
- WSL2 Documentation: [Microsoft WSL Docs](https://docs.microsoft.com/en-us/windows/wsl/)
- Nix Documentation: [Nix Manual](https://nixos.org/manual/nix/stable/)
- Community Support: Stack Overflow, NixOS Discourse

---

## Quick Reference

### Essential Commands
```bash
# System status
dot doctor                    # Run dotfiles health check
wsl --status                 # WSL2 status
nix profile list             # List Nix packages
chezmoi status               # Chezmoi status

# Quick fixes
chezmoi apply                # Reapply dotfiles
source ~/.zshrc              # Reload shell config
nix-collect-garbage          # Clean Nix store
sudo systemctl restart nix-daemon  # Restart Nix daemon

# Emergency access
/bin/bash --noprofile        # Clean shell
export PATH=/usr/bin:/bin    # Minimal PATH
```

### Recovery Commands
```bash
# Nuclear options (use with caution)
rm -rf ~/.local/share/chezmoi/     # Reset chezmoi
sudo rm -rf /nix/                  # Remove Nix completely
wsl --unregister Ubuntu            # Reset WSL2 (from PowerShell)
```

This guide covers the most common WSL2 and Nix edge cases. For issues not covered here, refer to the specific tool documentation or create a support request with the diagnostic information provided.

### Validation Checklist

Before reporting issues, verify your environment with these commands:

```bash
# WSL2 Environment Check
echo "=== WSL2 Environment Check ==="
uname -a
cat /proc/version | grep -i wsl || echo "Not running in WSL2"
mount | grep drvfs | head -3
df -h / /tmp

# Nix Installation Check
echo "=== Nix Installation Check ==="
command -v nix && nix --version || echo "Nix not installed"
echo $NIX_PATH
ls -la ~/.config/nix/ 2>/dev/null || echo "No Nix config directory"

# Dotfiles Status Check
echo "=== Dotfiles Status Check ==="
command -v chezmoi && chezmoi --version || echo "Chezmoi not installed"
cd ~/.dotfiles && git status --porcelain || echo "Not in dotfiles directory"
ls -la ~/.dotfiles/nix/flake.nix 2>/dev/null || echo "Nix flake not found"

# Performance Check
echo "=== Performance Check ==="
time ls ~/.dotfiles >/dev/null
free -m 2>/dev/null || vm_stat | head -5
```

Run this checklist and include the output when requesting support.