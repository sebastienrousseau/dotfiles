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

## 🔐 Security
Refer to [SECURITY.md](../.github/SECURITY.md) for vulnerability reporting and security policies.
