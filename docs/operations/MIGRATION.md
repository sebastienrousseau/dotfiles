# Migration & Upgrade Guide

## Upgrade Workflow

```bash
# 1. Pre-upgrade check
dot doctor

# 2. Pull latest changes
cd ~/.dotfiles && git pull

# 3. Apply with diagnostics
dot apply

# 4. Post-upgrade verification
dot doctor
```

## Version History

### v0.2.499 (Current)
- Added AI CLIs: Autohand Code, Mistral Vibe, Qwen Code, ZAI
- Removed Cline CLI (broken upstream dependency)
- Interactive mise installer for missing AI providers
- Mise-first provisioning for all AI tools
- User extension points: rc.d.local, modules.d, custom dot commands
- SSH config hardening template
- Ghostty and WezTerm terminal configs
- Modern CLI tools: delta, fd, dust, bottom, lazygit, lazydocker, tldr
- Auto-prewarm after dot apply
- Expanded Atuin history filters

### v0.2.498
- Theme system with Catppuccin integration
- Linux desktop parity (Niri, Waybar, Fuzzel)
- AI tooling expansion (Kiro, OpenCode)
- Coverage contracts and QA docs

### v0.2.497
- Verified chezmoi installer
- Shell startup optimization
- Property-based tests

## Breaking Changes

If upgrading from v0.2.497 or earlier:

1. **Cline CLI removed** — if you used `dot cline`, switch to another AI CLI
2. **AI tools now install via mise** — run `mise install` to update AI providers
3. **SSH config hardening** — review `~/.ssh/config` after apply; may override existing settings

## Rollback

If an upgrade causes issues:

```bash
# Quick rollback to previous state
dot rollback

# Rollback to specific backup
dot rollback status       # List available backups
dot rollback rollback-to 3  # Restore backup #3

# Git-based rollback
cd ~/.dotfiles
git log --oneline -10     # Find last good commit
git reset --hard HEAD~1   # Reset to previous commit
dot apply                 # Re-apply
```

## Pre-Upgrade Checklist

- [ ] Run `dot doctor` — verify current state is healthy
- [ ] Check `dot diff` — review pending changes
- [ ] Backup custom configs: `dot rollback backup`
- [ ] Read CHANGELOG.md for breaking changes

## Post-Upgrade Checklist

- [ ] Run `dot doctor` — verify upgrade succeeded
- [ ] Run `dot prewarm` — regenerate shell caches
- [ ] Restart shell: `exec zsh`
- [ ] Test AI tools: `dot ai`
