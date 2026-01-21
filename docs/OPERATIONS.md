# Operational Guide

This document outlines the standard workflows for maintaining and operating the dotfiles configuration.

## 🔄 Daily Usage

### Applying Changes
To apply the latest configuration to your local machine:
```bash
chezmoi apply
```
*Note: This will trigger the Audit Log (`~/.dotfiles_audit.log`).*

### Updating from Remote
To pull the latest changes from the repository and apply them:
```bash
chezmoi update
```

## 🛠️ Development

### Adding a New File
To start tracking a file with `chezmoi`:
```bash
chezmoi add ~/.config/path/to/file
```

### Editing Configuration
To edit a tracked file (opens in your default editor):
```bash
chezmoi edit ~/.zshrc
```

### Testing Changes
To see what changes `chezmoi` would apply without actually applying them:
```bash
chezmoi diff
```

## 📊 Monitoring & Performance

### Audit Logs
Every `chezmoi apply` event is logged. To view the history:
```bash
tail -f ~/.dotfiles_audit.log
```

### Performance Benchmarking
To measure shell startup time against the <20ms target:
```bash
./scripts/benchmark.sh
```

## 🔐 Security & Identity

### 1. Verify 1Password Agent
Ensure the core secrets manager is active:
```bash
op account get
```
*Should return your account details.*

### 2. Verify Git Signing
Ensure generic Git operations are signed via SSH + 1Password:
```bash
git config --get gpg.format  # Should differ "ssh"
ssh-add -l                   # Should list your 1Password key
```

---

## 🧠 Memory & Sync (Atuin)

### Initial Setup
To enable history sync across devices:
```bash
atuin login
atuin import auto  # Import old history
atuin sync
```

### Usage
- **Ctrl-r**: Open history search.
- **Up Arrow**: Filter history by current command.

---

## 🎨 Visual Tools Cheatsheet

| Command | Tool | Action |
|---|---|---|
| `y` | **Yazi** | Open file manager. |
| `zj` | **Zellij** | Launch terminal workspace. |
| `lg` | **LazyGit** | Open Git TUI. |

---

## 🔐 Security
Refer to [SECURITY.md](../.github/SECURITY.md) for vulnerability reporting and security policies.
