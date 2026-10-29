---
render_with_liquid: false
---

# Cookbook: Recipes

Short recipes for common tasks.

## Installation & Update

### 1. Install on a fresh machine

```sh
# After the verified release download in the installation guide:
bash /tmp/dotfiles-install.sh
```

### 2. Update everything

```sh
dot system update
```

### 3. Update dotfiles only (no tools)

```sh
dot config update
```

### 4. Preview what would change

```sh
chezmoi apply --dry-run --verbose
```

`dot apply --dry-run` passes `--dry-run` to chezmoi but still runs the
post-apply steps (snapshot, repair, cache pre-warm), so call chezmoi
directly for a pure preview.

## Themes

### 5. Switch to a specific theme

```sh
dot theme set tahoe-dark
```

### 6. Toggle between dark and light

```sh
dot theme toggle
```

### 7. Open the interactive theme picker

```sh
dot theme
```

### 8. List paired wallpaper themes

```sh
dot theme list
```

### 9. Add a new wallpaper-driven theme

```sh
cp my-wallpaper.jpg ~/Pictures/Wallpapers/myname-dark.jpg
cp my-wallpaper-light.jpg ~/Pictures/Wallpapers/myname-light.jpg
bash scripts/theme/merge-wallpaper.sh myname
dot theme rebuild
dot theme set myname-dark
```

### 10. Regenerate all themes from scratch

```sh
dot theme rebuild --force
```

## Configuration

### 11. Edit the source directory

```sh
dot edit
```

### 12. Add a new config file to chezmoi

```sh
dot config add ~/.some-config-file
```

### 13. Remove a managed file

```sh
chezmoi forget ~/.some-config-file
```

`chezmoi forget` stops managing the file and leaves it in place.

### 14. Show configuration drift

```sh
dot status
```

### 15. Show diff against source

```sh
dot diff
```

## Secrets

### 16. Encrypt a new secret file

```sh
chezmoi add --encrypt ~/some-secret.txt
```

### 17. Edit an encrypted file

```sh
sops path/to/file.sops.yaml
# or, for a file added with chezmoi add --encrypt:
chezmoi edit ~/some-secret.txt
```

### 18. Rotate your Age key

```sh
# SOPS key (~/.config/sops/age/keys.txt):
age-keygen -o ~/.config/sops/age/new-key.txt
# Put the new public key (printed above) in .sops.yaml. Keep the old key
# in keys.txt so sops can still decrypt, then re-encrypt:
cat ~/.config/sops/age/new-key.txt >> ~/.config/sops/age/keys.txt
find . -name '?*.sops.yaml' -exec sops updatekeys {} \;
git commit -sS -am "chore(secrets): rotate age key"
```

### 19. Check for accidental secret leaks

```sh
dot secret check
```

## Diagnostics

### 20. Quick health check

```sh
dot doctor
```

### 21. Auto-fix common issues

```sh
dot doctor fix
```

### 22. Check startup performance

```sh
dot doctor perf measure
```

### 23. See the health score

```sh
dot doctor score show
```

### 24. Recent metrics

```sh
dot doctor metric list
```

## Fleet

### 25. Publish this host's attestation to a shared fleet store

```sh
dot attest show --fleet-store /path/to/fleet-store
```

Run it on each host; the evidence lands under
`<store>/<fleet-id>/<hostname>/`.

### 26. Sync dotfiles to every fleet host

```sh
dot fleet apply --cmd 'dot config update'   # pull and apply on each host in fleet.toml
```

Without `--cmd`, each host runs `dot sync && dot doctor --quiet`, which
applies the checkout already on that host without pulling.

### 27. Check drift on every fleet host

```sh
dot fleet apply --cmd 'dot status'
```

## AI & Agents

### 28. Show installed AI tools

```sh
dot ai list
```

### 29. Switch agent mode

```sh
dot agent mode set plan   # or ask, apply, audit
```

### 30. Verify MCP policy

```sh
dot mcp check --strict
```

## Recovery

### 31. Rollback the last apply

```sh
dot doctor rollback            # list the backups
dot doctor rollback rollback   # restore the newest one (asks first)
```

### 32. Create an offline bundle

```sh
dot config export            # writes ~/Downloads/dotfiles_offline_bundle_<timestamp>.tar.zst
dot config export ~/backups  # or into another directory
```

The bundle holds `~/.dotfiles`, `~/.config/chezmoi` and `~/.local/share/mise`.
It leaves out your age key (any file there with an `AGE-SECRET-KEY` line) and
names it: carry the key to the other machine separately.

### 33. Restore from a bundle

```sh
tar --zstd -xf ~/Downloads/dotfiles_offline_bundle_*.tar.zst -P
cd ~/.dotfiles && ./install.sh --force
```

The archive stores absolute paths, so restore it as the same user with the
same home directory. `dot config import` does not restore a bundle today:
it creates a new one instead.

## Development

### 34. Run a test locally

```sh
bash tests/unit/theme/test_themes_toml.sh
```

### 35. Run all tests

```sh
./tests/framework/test_runner.sh
```

### 36. Lint shell scripts

```sh
dot config check
```

### 37. Simulate chaos to test self-healing

```sh
bash scripts/ops/chaos.sh --force   # from the repo, in an ephemeral container only
dot doctor fix
dot doctor
```

## Manual

### 38. Open the manual in a browser

```sh
dot help --manual
```

### 39. Download the PDF

```sh
dot help --manual pdf
```

### 40. Read the manual in a terminal

```sh
dot help --manual text | less
```

## See Also

- [Troubleshooting](02-troubleshooting.md)
- [FAQ](03-faq.md)
- [CLI Reference](../03-reference/01-dot-cli.md)
