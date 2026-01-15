# Dotfiles Health Check & CI Documentation

## Overview

The health check system validates your dotfiles setup with comprehensive diagnostics, performance monitoring, and CI integration.

**New Features:**
- 🎯 **Machine Profiles**: Custom thresholds for laptop/server/ci/development
- 📊 **Baseline Metrics**: Track performance over time, detect regressions
- 🔍 **Audit Mode**: Read-only reporting for new machines
- ✅ **Self-Check**: CI validates the health check script itself

**Quick Start:**
```bash
# Standard check
dotfiles doctor

# Save baseline (do this first!)
dotfiles doctor --baseline

# Server with relaxed thresholds
dotfiles doctor --profile server

# Audit mode (never fails)
dotfiles doctor --audit

# Help
dotfiles doctor --help
```

**📖 For detailed documentation on profiles, metrics, audit mode, and self-check:**
→ See [PROFILES_AND_METRICS.md](PROFILES_AND_METRICS.md)

---

## Health Check Command

### Usage

Run the health check using any of these methods:

```bash
# Direct script execution
~/.dotfiles/scripts/doctor.sh

# Via dotfiles CLI (requires PATH setup)
dotfiles doctor

# Via Makefile
cd ~/.dotfiles && make doctor
```

### What It Checks

#### 1. **Shell Startup Performance**
- Measures Zsh and Bash startup times
- Thresholds:
  - ✅ Excellent: < 150ms
  - ✅ Good: < 250ms  
  - ⚠️  Acceptable: < 500ms
  - ❌ Slow: > 500ms

#### 2. **Required Files**
- Verifies presence of key configuration files
- Checks dotfiles directory structure

#### 3. **Duplicate Sourcing Detection**
- Detects multiple `compinit` calls
- Detects multiple `mise activate` calls
- Checks for circular sourcing between files

#### 4. **PATH Sanity**
- Counts PATH entries (warns if > 40)
- Detects duplicate PATH entries
- Finds non-existent directories in PATH
- Checks for world-writable directories (security risk)
- Checks for relative paths (security risk)

#### 5. **Shell Syntax Validation**
- Validates `.zshrc` syntax
- Validates `.bashrc` syntax
- Validates `.profile` syntax

#### 6. **Cache Status**
- Checks age of dotfiles caches
- Checks completion cache status
- Warns if caches are stale (> 24h)

#### 7. **Environment Variables**
- Verifies critical variables are set:
  - `DOTFILES_VERSION`
  - `DOTFILES`
  - `SHELL`
  - `HOME`

#### 8. **Security Checks**
- Verifies shell config file permissions
- Checks `~/.ssh` permissions (should be 0700)
- Checks `~/.gnupg` permissions (should be 0700)

### Exit Codes

- `0` - All checks passed (or warnings only)
- `1` - Errors found that need attention

---

## CI/CD Pipeline

### Overview

The CI pipeline runs automatically on:
- Push to `main`, `master`, or `develop` branches
- Pull requests to those branches
- Changes to shell files (`.sh`, `.zshrc`, `.bashrc`, etc.)

### Jobs

#### 1. **ShellCheck Linting**
- Runs ShellCheck on all `.sh` files
- Validates shell script best practices
- Severity level: warning

#### 2. **Syntax Validation** 
- Runs on both Ubuntu and macOS
- Tests both Bash and Zsh syntax
- Ensures configs work cross-platform

#### 3. **Startup Performance Test**
- Measures shell startup time on Ubuntu and macOS
- Runs 3 iterations to get average
- Helps detect performance regressions

#### 4. **Health Check**
- Runs the full `doctor.sh` script
- Tests in clean environment
- Validates overall setup health

#### 5. **Security Scan**
- Checks for hardcoded secrets/passwords
- Detects hardcoded user paths (e.g., `/Users/username`)
- Verifies no world-writable files

### Local Testing Before Commit

```bash
# Validate syntax locally
zsh -n ~/.zshrc
bash -n ~/.bashrc

# Run ShellCheck (if installed)
shellcheck lib/**/*.sh scripts/**/*.sh

# Run health check
dotfiles doctor

# Test startup time
time zsh -ilc exit
time bash -ilc exit
```

### GitHub Actions Workflow

The CI workflow is defined in `.github/workflows/shell-ci.yml`.

To manually trigger the workflow:
```bash
# Via GitHub CLI
gh workflow run shell-ci.yml

# Via GitHub UI
Actions → Shell Configuration CI → Run workflow
```

---

## Setup Instructions

### Enable the dotfiles Command

The `dotfiles` command requires `~/.dotfiles/bin` to be in your PATH.

**Already configured!** The path was added to `~/.dotfiles/lib/paths/default.paths.sh`.

After reloading your shell, you can use:
```bash
dotfiles doctor    # Run health check
dotfiles version   # Show version
dotfiles help      # Show help
```

### First-Time Setup

1. **Reload your shell** to apply PATH changes:
   ```bash
   exec zsh
   # or
   source ~/.zshrc
   ```

2. **Run initial health check**:
   ```bash
   dotfiles doctor
   ```

3. **Fix any errors** reported by the health check

4. **Commit changes** (triggers CI):
   ```bash
   cd ~/.dotfiles
   git add .
   git commit -m "Add health check and CI pipeline"
   git push
   ```

### When Moving to a New Machine

```bash
# Clone your dotfiles
git clone <your-repo> ~/.dotfiles

# Install/copy dotfiles
cd ~/.dotfiles
make install  # or your installation command

# Run health check
make doctor

# Fix any issues found
# Then reload shell
exec zsh
```

---

## Troubleshooting

### "dotfiles: command not found"

**Solution**: Reload your shell or add to PATH manually:
```bash
export PATH="$HOME/.dotfiles/bin:$PATH"
```

### CI Fails on ShellCheck

**Solution**: Fix the issues locally first:
```bash
brew install shellcheck  # macOS
sudo apt install shellcheck  # Ubuntu

shellcheck path/to/script.sh
```

### Startup Time Test Fails

**Solution**: Run locally to debug:
```bash
time zsh -ilx -c exit 2>&1 | grep -E "compinit|mise|source"
```

---

## Maintenance

### Regular Health Checks

Run weekly or after major changes:
```bash
dotfiles doctor
```

### Update Thresholds

Edit `scripts/doctor.sh` to adjust performance thresholds:
```bash
# Line ~88-95 for startup time thresholds
if [[ $zsh_ms -lt 150 ]]; then
    check_pass "Zsh startup: ${zsh_ms}ms (excellent)"
elif [[ $zsh_ms -lt 250 ]]; then
    check_pass "Zsh startup: ${zsh_ms}ms (good)"
# ... adjust as needed
```

### Add Custom Checks

Add new check functions in `scripts/doctor.sh`:
```bash
check_custom_feature() {
    print_section "Custom Feature"
    
    # Your checks here
    if [[ condition ]]; then
        check_pass "Feature works"
    else
        check_fail "Feature broken"
    fi
    
    echo ""
}

# Add to main():
main() {
    # ... existing checks
    check_custom_feature
    # ...
}
```

---

## References

- [ShellCheck Documentation](https://github.com/koalaman/shellcheck)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Dotfiles Best Practices](https://dotfiles.io)
