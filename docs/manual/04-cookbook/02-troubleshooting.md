# Cookbook: Troubleshooting

Symptom → cause → fix.

## Installation

### Symptom: `install.sh` fails with "chezmoi not found"

**Cause**: `/usr/local/bin` or `~/.local/bin` not in PATH at install time.

**Fix**:
```sh
export PATH="$HOME/.local/bin:$PATH"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
```

### Symptom: "could not create directory ~/.local/share/chezmoi"

**Cause**: Permission issue on `~/.local`.

**Fix**:
```sh
mkdir -p ~/.local/share ~/.local/state ~/.local/bin
chmod 755 ~/.local ~/.local/share
```

### Symptom: Install hangs at "Downloading chezmoi"

**Cause**: Slow network or corporate proxy.

**Fix**:
```sh
export https_proxy=$HTTP_PROXY  # if applicable
# Or pre-download chezmoi manually
brew install chezmoi            # macOS
apt install chezmoi             # Debian 13+
```

## Apply / Sync

### Symptom: `dot apply` reports "file modified, skipping"

**Cause**: Chezmoi detected local drift on a managed file.

**Fix**:
```sh
dot diff                    # see what differs
dot apply --force           # overwrite local
# OR
dot add <path>              # import local change to source
```

### Symptom: "template: error calling index"

**Cause**: A template references a missing data field.

**Fix**: Check that your `.chezmoidata.toml` has the required field. For example:
```sh
chezmoi execute-template '{{- $hw := index .hardware .machine -}}{{ $hw.wm }}'
```
If `machine` is not set in your `~/.config/chezmoi/chezmoi.toml`, `index` returns nil. Set:
```toml
[data]
machine = "macbook-t2"
```

### Symptom: Apply succeeds but shell doesn't reflect changes

**Cause**: Cached init scripts are stale.

**Fix**:
```sh
dot clean-cache
dot prewarm
exec $SHELL -l
```

## Theme

### Symptom: `dot theme` shows no themes

**Cause**: No wallpapers discovered, themes.toml not generated.

**Fix**:
```sh
dot theme rebuild --force
```

### Symptom: `dot theme <name>` errors "unknown theme"

**Cause**: Theme name doesn't exist in `themes.toml`.

**Fix**:
```sh
dot theme list            # see valid names
dot theme rebuild --force # regenerate if expected but missing
```

### Symptom: macOS accent color doesn't update

**Cause**: System Settings UI cached the old value.

**Fix**: `dot-theme-sync` now calls `killall cfprefsd SystemUIServer Dock "System Settings"`. If it still doesn't refresh:
```sh
killall -KILL Dock SystemUIServer
sudo killall -KILL cfprefsd
```
Or log out and back in.

### Symptom: Wallpaper not applying

**Cause**: Wrong format or missing DE support on Linux.

**Fix**:
```sh
# Check the wallpaper file exists
ls -la ~/Pictures/Wallpapers/

# On Linux, verify HEIC → PNG conversion tool
command -v magick || command -v heif-convert || command -v convert
# Install if needed:
sudo apt install imagemagick-7
```

### Symptom: Theme applies but Ghostty doesn't reload

**Cause**: Ghostty DBus or SIGUSR2 signaling failed.

**Fix**:
```sh
# Restart Ghostty manually, or:
pkill -USR2 ghostty 2>/dev/null
# Or quit+relaunch the app
```

## Secrets

### Symptom: "could not decrypt: no age key"

**Cause**: `~/.config/age/keys.txt` missing or unreadable.

**Fix**:
```sh
ls -la ~/.config/age/keys.txt
# Should be: -rw------- 1 user user
chmod 600 ~/.config/age/keys.txt

# If missing, restore from password manager or regenerate (requires re-encrypting all secrets)
```

### Symptom: SOPS says "wrong recipient"

**Cause**: Your Age public key isn't listed in the file's recipients.

**Fix**:
```sh
# Add your public key to .sops.yaml
sops updatekeys path/to/file.sops.yaml

# Or, ask a recipient to re-encrypt for you
```

### Symptom: Plaintext leak detected by gitleaks

**Cause**: A secret was committed to Git history.

**Fix**:
```sh
# Immediate mitigation
dot verify --security   # confirm which file
git rm --cached <file>
echo "<file>" >> .gitignore
git commit -sS -m "fix(security): remove leaked file"

# Rotate the leaked secret upstream (it's now public)
# Rewrite Git history if needed (requires force-push):
git filter-repo --path <file> --invert-paths
```

## Performance

### Symptom: Shell startup >500ms

**Cause**: Heavy modules loaded synchronously.

**Fix**:
```sh
dot benchmark --detailed
# Identify which module is slow

# Rebuild caches
dot prewarm

# Disable heavy modules temporarily
# Edit ~/.config/zsh/.zshrc.local (or equivalent) to skip them
```

### Symptom: `dot doctor` score <70

**Cause**: Multiple health issues.

**Fix**:
```sh
dot doctor --verbose    # see every failure
dot heal                # auto-fix what's possible
dot doctor              # recheck
```

### Symptom: Mise tools not found

**Cause**: Mise shim not activated.

**Fix**:
```sh
eval "$(mise activate zsh)"  # or fish, bash
dot doctor                    # confirm
```

## Build Artifacts

### Symptom: Cargo builds to `target/` instead of `/tmp/builds/cargo`

**Cause**: `~/.cargo/config.toml` not managed or was overridden.

**Fix**:
```sh
chezmoi apply ~/.cargo/config.toml
cat ~/.cargo/config.toml | grep target-dir
# Should be: target-dir = "/tmp/builds/cargo"
```

### Symptom: `/tmp/builds/` doesn't exist

**Cause**: Created by shell init, but shell wasn't restarted.

**Fix**:
```sh
mkdir -p /tmp/builds
# Or restart shell
exec $SHELL -l
```

## Fleet

### Symptom: `dot fleet attest` hangs

**Cause**: A fleet host is unreachable.

**Fix**:
```sh
# Check connectivity to each host
for host in macbook-t2 surface-pro geekom-a9; do
  ssh -o ConnectTimeout=5 $host 'echo OK' || echo "FAIL: $host"
done

# Remove unreachable hosts from ~/.config/dotfiles/fleet.toml temporarily
```

### Symptom: Attestation signature fails

**Cause**: Remote host's SSH public key not in local `~/.ssh/allowed_signers`.

**Fix**:
```sh
# On the remote host:
ssh remote-host 'cat ~/.ssh/id_ed25519.pub'
# Copy the output and append to your ~/.ssh/allowed_signers
```

## CI

### Symptom: PR fails on "Shell Lint (Zero Warnings)"

**Cause**: `shfmt` formatting differs from canonical.

**Fix**:
```sh
shfmt -w -i 2 -ci scripts/**/*.sh install.sh .chezmoitemplates/**/*.sh
# Commit the changes
```

### Symptom: PR fails on "100% Coverage"

**Cause**: New code added without tests.

**Fix**:
```sh
bash examples/example-coverage-gate.sh
# Identifies uncovered modules

# Add a test in tests/unit/<domain>/test_<module>.sh
```

### Symptom: Checkov SARIF upload times out

**Cause**: Known infrastructure flake (Azure runner slow apt mirrors).

**Fix**: The workflow already guards this with `hashFiles('reports/checkov.sarif')`. If you see this after the guard was added, check the Checkov step output for errors.

## Getting More Help

1. Check [FAQ](03-faq.md)
2. Read the relevant [concept chapter](../01-concepts/)
3. Open an issue: <https://github.com/sebastienrousseau/dotfiles/issues>

When filing an issue, include:

```sh
dot doctor --json
dot version
uname -a
chezmoi --version
```

## See Also

- [Self-Healing concept](../01-concepts/05-self-healing.md)
- [FAQ](03-faq.md)
- [Security: Incident Response](../../security/INCIDENT_RESPONSE.md)
