# Migration and Upgrade Guide

## How to Upgrade

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

### v0.2.500 (Current)
- **Wallpaper-driven theme engine** — themes auto-generated from wallpapers via K-Means in CIELAB color space (no hand-crafted themes)
- **Dynamic HEIC support** — custom wallpapers ship as Apple-compatible single-file dynamic HEIC; macOS auto-switches dark/light
- **System wallpaper discovery** — pulls themes from `/System/Library/Desktop Pictures/` (macOS) and `/usr/share/backgrounds/` (Linux)
- **`dot theme rebuild`** — parallel K-Means generation (4 jobs), mtime-based caching, orphan cleanup
- **WCAG AAA enforcement** — all generated themes pass 7:1 contrast for fg/bg, accent_text/accent, c15/bg
- **macOS accent from wallpaper hue** — `dot-theme-sync` reads `macos_accent` from themes.toml and forces UI refresh
- **HEIC → PNG auto-conversion** on Linux for non-HEIC-aware desktops
- **Build artifact redirection** — Cargo, Go, pip, uv, Zig caches → `/tmp/builds/` (cleared on reboot)
- **CI dedup** — `ci-enforced.yml` reuses `reusable-shell-lint.yml` and `reusable-test-suite.yml`

### v0.2.499
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

If you are upgrading from v0.2.499 or earlier, note these changes:

1. **`themes.toml` is now generated** — do not hand-edit. Run `dot theme rebuild` to regenerate from wallpapers
2. **Theme names changed** — old hand-crafted names (e.g. `catppuccin-mocha`, `macos-tahoe-dark` with hardcoded palettes) are replaced by wallpaper-derived names. The picker only shows paired wallpaper themes.
3. **Wallpaper format** — custom wallpapers should be dynamic HEIC (single file, both appearances). Use `bash scripts/theme/merge-wallpaper.sh` to merge separate dark/light pairs.
4. **Build caches relocated** — Cargo/Go/pip/uv/Zig now write to `/tmp/builds/`. Restart your shell after upgrade so `mise [env]` picks up the new paths.

If you are upgrading from v0.2.498 or earlier:

1. **Cline CLI removed** — if you used `dot cline`, switch to a different AI CLI
2. **AI tools now install through mise** — run `mise install` to set up AI providers
3. **SSH config hardening** — check `~/.ssh/config` after apply, as it may change your current settings

## Rollback

If something goes wrong after an upgrade:

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

## Before You Upgrade

- [ ] Run `dot doctor` — make sure everything is healthy
- [ ] Run `dot diff` — review any pending changes
- [ ] Back up custom configs: `dot rollback backup`
- [ ] Read CHANGELOG.md for breaking changes

## After You Upgrade

- [ ] Run `dot doctor` — make sure the upgrade worked
- [ ] Run `dot prewarm` — rebuild shell caches
- [ ] Restart your shell: `exec zsh`
- [ ] Test AI tools: `dot ai`
