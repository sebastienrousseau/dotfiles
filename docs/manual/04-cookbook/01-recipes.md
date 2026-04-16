# Cookbook: Recipes

Thirty short recipes for common tasks.

## Installation & Update

### 1. Install on a fresh machine

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
```

### 2. Update everything

```sh
dot upgrade
```

### 3. Update dotfiles only (no tools)

```sh
dot update
```

### 4. Preview what would change

```sh
dot apply --dry-run
```

## Themes

### 5. Switch to a specific theme

```sh
dot theme tahoe-dark
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
dot theme myname-dark
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
dot add ~/.some-config-file
```

### 13. Remove a managed file

```sh
dot remove ~/.some-config-file
```

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
sops dot_config/credentials.sops.yaml
# or
chezmoi edit ~/some-secret.txt.age
```

### 18. Rotate your Age key

```sh
age-keygen -o ~/.config/age/keys.txt.new
# Update .sops.yaml with new public key
# Then:
find . -name '*.sops.yaml' -exec sops updatekeys {} \;
git commit -sS -am "chore(secrets): rotate age key"
```

### 19. Check for accidental secret leaks

```sh
dot verify --security
```

## Diagnostics

### 20. Quick health check

```sh
dot doctor
```

### 21. Auto-fix common issues

```sh
dot heal
```

### 22. Check startup performance

```sh
dot benchmark
```

### 23. See the health score

```sh
dot score
```

### 24. Recent metrics

```sh
dot metrics
```

## Fleet

### 25. Attest across all fleet hosts

```sh
dot fleet attest
```

### 26. Sync dotfiles to every fleet host

```sh
dot fleet sync
```

### 27. Diff config across hosts

```sh
dot fleet diff
```

## AI & Agents

### 28. Show installed AI tools

```sh
dot ai
```

### 29. Switch agent profile

```sh
dot mode architect   # or hardener, refactor
```

### 30. Verify MCP policy

```sh
dot mcp --strict
```

## Recovery

### 31. Rollback the last apply

```sh
dot rollback
```

### 32. Create an offline bundle

```sh
dot bundle
```

### 33. Restore from a bundle

```sh
dot bundle restore ~/Downloads/dotfiles-bundle-*.tar.zst
```

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
dot lint
```

### 37. Simulate chaos to test self-healing

```sh
dot chaos symlink   # in an ephemeral container only
dot heal
dot doctor
```

## Manual

### 38. Open the manual in a browser

```sh
dot manual
```

### 39. Download the PDF

```sh
dot manual pdf
```

### 40. Read the manual in a terminal

```sh
dot manual text | less
```

## See Also

- [Troubleshooting](02-troubleshooting.md)
- [FAQ](03-faq.md)
- [CLI Reference](../03-reference/01-dot-cli.md)
